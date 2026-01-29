// UNITY_SHADER_NO_UPGRADE

// A collection of effects made by xwidghet to allow for creating dynamic stereo-correct shader animations
// which can be combined together without creating massive performance issues.
//
// This has only been tested on the Valve Index, VRChat Desktop mode and Unity Editor.
// However I haven't heard from anyone I know using the HTC Vive, Oculus CV1, or Samsung Odyssey+ complain
// about anything causing issues. I would be interested to know if features like meme images work
// correctly on high FOV headsets such as the ones from Pimax.
//
// Effect implementations take parameters, rather than reading the shader parameters
// directly, to allow for combining them together to create more powerful effects
// without copy-pasting code. 
//
// ex. Geometric Dither is created by using SkewX and SkewY repeatedly with varying parameter values
//
// LICENSE: This shader is licensed under GPL V3.
//			https://www.gnu.org/licenses/gpl-3.0.en.html
//
//			This shader makes use of the perlin noise generator from https://github.com/keijiro/NoiseShader
//			which is licensed under the MIT License.
//			https://opensource.org/licenses/MIT
//
//			This shader also makes use of the voroni noise generator created by Ronja Böhringer,
//			which is licensed under the CC-BY 4.0 license (https://creativecommons.org/licenses/by/4.0/)
//			https://github.com/ronja-tutorials/ShaderTutorials
//
//			Various math helpers shared on the internet without an explicitly stated license
//			are included in CancerHelper.cginc.
//			Math helpers written by me start at the comment "// Begin xwidghet helpers"
//			and end before the comment "// End xwidghet helpers".
//
//			See LICENSE for more info.

#ifndef STEREO_CANCER_FUNCTIONS_CGINC
#define STEREO_CANCER_FUNCTIONS_CGINC

// For SPS-I macros, such as UNITY_SAMPLE_TEX2DARRAY
#include "HLSLSupport.cginc"

// Returns true when the vertex or fragment should not be visible
bool mirrorCheck(float cancerDisplayMode)
{
	// https://docs.vrchat.com/docs/vrchat-202231
	// 1 is Mirror VR and 2 is Mirror Desktop.
	bool isMirror = _VRChatMirrorMode > 0;

	// cancerDisplayMode == 0: Display on screen only
	// cancerDisplayMode == 1: Display on mirror only
	// cancerDisplayMode >= 2: Display on both mirror and screen.
	return (cancerDisplayMode == 1 && !isMirror) || (cancerDisplayMode == 0 && isMirror);
}

// Expects stereo UV coordinates and depth to have been divided by w
float4 viewPosFromDepth(float4x4 invProj, float2 uv, float depth)
{
#ifdef UNITY_SINGLE_PASS_STEREO
	// Ensure both eye UVs are in the range of 0-1 for reverse projection later
	uv.x *= 2;
	uv.x -= step(1, unity_StereoEyeIndex);
#endif

	// Convert UV to clip space and retrieve the view position using inverse
	// matrix multiplication.
	// https://stackoverflow.com/questions/32227283/getting-world-position-from-depth-buffer-value
	float4 viewPos = mul(invProj, float4(uv.xy*2.0 - 1.0, depth, 1.0));

	return viewPos / viewPos.w;
}

float3 worldPosFromDepth(float4 depthSamplePos, float3 camPos, float4 worldCoordinates)
{
	float sampleDepth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, depthSamplePos);
	sampleDepth = DECODE_EYEDEPTH(sampleDepth);

	// https://gamedev.stackexchange.com/questions/131978/shader-reconstructing-position-from-depth-in-vr-through-projection-matrix
	float3 viewDirection = (worldCoordinates.xyz - camPos) / (-mul(UNITY_MATRIX_V, worldCoordinates).z);

	return camPos + viewDirection * sampleDepth;
}

  ///////////////////////////
 // Distortion functions ///
///////////////////////////

float4 computeWorldPositionFromAxisPosition(float4 worldCoordinates)
{
	// Need to unflip our x coordinate. This is because the normal screen-space
	// coordinate system is backwards compared to world coordinates.
	worldCoordinates.x *= -1;
	return mul(UNITY_MATRIX_I_V, worldCoordinates);
}

float4 computeStereoUV(float4 worldCoordinates)
{
	float4 screenCoords = mul(UNITY_MATRIX_VP, worldCoordinates);

	return ComputeGrabScreenPos(screenCoords);
}

float2 screenToEyeUV(float2 screenUV)
{
#ifdef UNITY_SINGLE_PASS_STEREO
	// Convert UV coordinates to eye-specific 0-1 coordiantes
	float offset = 0.5 * step(1, unity_StereoEyeIndex);
	float min = offset;
	float max = 0.5 + offset;

	float uvDist = max - min;
	screenUV.x = (screenUV.x - min) / uvDist;
#endif

	return screenUV;
}

float2 EyeUVToScreen(float2 screenUV)
{
#ifdef UNITY_SINGLE_PASS_STEREO
	float _offset = 0.5 * step(1, unity_StereoEyeIndex);
	float _min = _offset;
	float _max = 0.5 + _offset;

	float _uvDist = _max - _min;

	// Convert the eye-specific 0-1 coordinates back to 0-1 UV coordinates
	screenUV.x = (screenUV.x * _uvDist) + _min;
#endif

	return screenUV;
}

float4 clampUVCoordinates(float4 stereoCoordinates)
{
	float2 stereoUVPos = (stereoCoordinates.xy / stereoCoordinates.w);

	stereoUVPos = screenToEyeUV(stereoUVPos);
	stereoUVPos = clamp(stereoUVPos, 0, 1);
	stereoUVPos = EyeUVToScreen(stereoUVPos);

	stereoCoordinates.xy = stereoUVPos * stereoCoordinates.w;

	return stereoCoordinates;
}

float4 wrapUVCoordinates(float4 stereoCoordinates)
{
	float2 stereoUVPos = stereoCoordinates.xy / stereoCoordinates.w;

	// Wrap around by grabbing the fractional part of the UV
	// and convert back to stereo coordinates.
	stereoUVPos = frac(stereoUVPos);

	stereoCoordinates.xy = stereoUVPos * stereoCoordinates.w;

	return stereoCoordinates;
}

float4 wrapWorldCoordinates(float4 worldCoordinates, float wrapValue)
{
	wrapValue *= 200;
	float2 signs = sign(worldCoordinates.xy);

	// Adjust wrap value based on the Z coordinate to constrain
	// the pixels within the wrapValue bounds when Z-Axis movement
	// occurs. Ex. Move Z, Ripple, and Simplex/Voroni noise effects.
	wrapValue -= (abs(worldCoordinates.z - 100) / 100)*wrapValue;
	wrapValue = abs(wrapValue);

	// Shift all coordinates past the wrapping point to resolve
	// a discontinuity in the range (wrapValue/2, wrapValue).
	worldCoordinates.xy += signs.xy*wrapValue;

	// Finally wrap coordinates around.
	worldCoordinates.xy = frac(abs(worldCoordinates.xy) / wrapValue / 2)*signs.xy*wrapValue * 2 - signs.xy*wrapValue;

	return worldCoordinates;
}

float4 projectCoordinates(float4 worldCoordinates, float3 camPos, float3 viewVector)
{
	// Convert from world-axis aligned coordinates to world space coordinates.
	worldCoordinates.xyz = computeWorldPositionFromAxisPosition(worldCoordinates);

	// Reconstruct view coordinates from depth
	float4 uv = computeStereoUV(worldCoordinates);
	float depth = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, uv);

	// Use the length of the reconstructed view ray to adjust our position
	// and retain the custom world-axis aligned coordinate system.
	depth = length(viewPosFromDepth(inverse(UNITY_MATRIX_P), uv.xy / uv.w, depth / uv.w));
	worldCoordinates.xyz = viewVector.xyz * depth;

	return worldCoordinates;
}

float4 stereoQuantization(float4 worldCoordinates, float scale)
{
	// Add 0.5 to make it so that the center of the screen is on
	// the center of a quantization square, rather than the corner
	// between 4 squares.
	float2 intPos = floor(worldCoordinates.xy * scale + 0.5);
	worldCoordinates.xy = (intPos / scale);

	return worldCoordinates;
}

  /////////////////////
 // Color functions //
/////////////////////

float2 calculateUVFromAxisCoordinates(float4 axisCoordinates, float4 texture_ST, float4 texture_TexelSize)
{
	// Apply Tiling
	axisCoordinates.xy *= texture_ST.xy;

	// Stretch our coordinates to match the aspect ratio of the image
	// being overlayed.
	axisCoordinates.x *= texture_TexelSize.w / texture_TexelSize.z;

	// Interpret axis-aligned coordinates as UV coordinates
	float2 uv = axisCoordinates.xy / 50.0;

	uv.x = -uv.x;
	uv += 0.5;

	// Apply Offset
	uv += texture_ST.zw / 100;

	return uv;
}

float4 stereoImageOverlay(float4 axisCoordinates, float4 startingAxisAlignedPos,
	sampler2D memeImage, float4 memeImage_ST, float4 memeImage_TexelSize,
	int memeColumns, int memeRows, int memeCount, int memeIndex,
	float clampUV, float cutoutUV, inout bool dropMemePixels)
{
	float2 uv = calculateUVFromAxisCoordinates(axisCoordinates, memeImage_ST, memeImage_TexelSize);
	float2 startingUV = calculateUVFromAxisCoordinates(startingAxisAlignedPos, memeImage_ST, memeImage_TexelSize);
	float2 imageSizeScaler = rcp(float2(memeColumns, memeRows));

	dropMemePixels = false;
	if (cutoutUV)
	{
		// Adjust texture size to match the final image size when texture atlases are in use.
		memeImage_TexelSize.zw *= imageSizeScaler;

		float2 pxCoordinates = uv * memeImage_TexelSize.zw;
		if (pxCoordinates.x > memeImage_TexelSize.z - 1 || pxCoordinates.x < 0 || pxCoordinates.y > memeImage_TexelSize.w - 1 || pxCoordinates.y < 0)
			dropMemePixels = true;
	}
	if (clampUV)
	{
		uv = clamp(uv, 0, 1);
	}

	float2 ddScaler = float2(1.0, 1.0);

	// Flipbook
	if (memeColumns > 1 || memeRows > 1)
	{
		memeIndex = memeIndex % memeCount;

		float2 imageStartingOffset = float2(memeIndex % memeColumns, 0);
		imageStartingOffset.y = (memeRows - 1) - (memeIndex - (memeIndex % memeColumns)) / memeColumns;

		uv = imageStartingOffset * imageSizeScaler + imageSizeScaler * uv;
		ddScaler *= imageSizeScaler;
	}

	// Utilize ddx and ddy from the starting axis aligned coordiantes to resolve sampling artifacts when the texture wraps around.
	return tex2D(memeImage, uv.xy, ddx(startingUV.x)*ddScaler.x, ddy(startingUV.y)*ddScaler.y);
}

#endif