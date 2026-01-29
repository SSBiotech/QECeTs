// UNITY_SHADER_NO_UPGRADE

Shader "S&SBiotech/Vistek™ v1.2.1"
{
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
    // ex. Geometric Dither is created by using Skew repeatedly with varying parameter values
    //
    // LICENSE: This shader is licensed under GPL V3.
    //			https://www.gnu.org/licenses/gpl-3.0.en.html
    //
    //			This shader makes use of the perlin noise generator from https://github.com/keijiro/NoiseShader
    //			which is licensed under the MIT License.
    //			https://opensource.org/licenses/MIT
    //
    //			This shader also makes use of the voroni noise generator created by Ronja Bohringer,
    //			which is licensed under the CC-BY 4.0 license (https://creativecommons.org/licenses/by/4.0/)
    //			https://github.com/ronja-tutorials/ShaderTutorials
    //
    //			Various math helpers shared on the internet without an explicitly stated license
    //			are included in CancerHelper.cginc.
    //			Math helpers written by me start at the comment "// Begin xwidghet helpers"
    //			and end before the comment "// End xwidghet helpers".
    //
    //			See LICENSE for more info.

    Properties
    {
        // Rendering Parameters
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 1
        [Enum(Off, 0, On, 1)] _ZWrite("Z Write", Int) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest("Z Test", Int) = 8

        [Enum(Normal, 0, No Reflection, 1, Render Only In Mirror, 2)] _MirrorMode ("Mirror Reflectance", Int) = 0
        [Enum(Both, 0, Left, 1, Right, 2)] _EyeSelector ("Eye Discrimination", Int) = 0
        [Enum(Both, 0, Desktop, 1, VR, 2)] _PlatformSelector ("Platform Discrimination", Int) = 0

        // VRChat workarounds
        [Enum(No, 0, Yes,1)] _DisableNameplates("Disable Nameplates", Int) = 0

        [Enum(Screen,0, Mirror,1, Both,2)] _CancerDisplayMode("Cancer Display Mode", Float) = 0
        [Enum(Fullscreen,0, World Scale,1)] _ObjectDisplayMode("Object Display Mode", Float) = 0
        [Enum(No, 0, Yes,1)] _DisplayOnSurface("Display On Surface", Float) = 0
        [Enum(Clamp,0, Eye Clamp,1, Wrap,2)] _ScreenSamplingMode("Screen Sampling Mode", Float) = 1
        [Enum(Screen,0, Projected (Requires Directional Light),1, Centered On Object,2)] _CoordinateSpace("Coordinate Space", Float) = 0
        _CoordinateScale("Coordinate Scale", Float) = 1
        [Enum(Wrap,0, Cutout,1, Clamp,2, Empty Space,3)] _WorldSamplingMode("World Sampling Mode", Float) = 0
        _WorldSamplingRange("World Sampling Range", Range(0, 1)) = 1
        _CancerEffectQuantization("Cancer Effect Quantization", Range(0, 1)) = 0
        _CancerEffectRotation("Cancer Effect Rotation", Float) = 0
        _CancerEffectOffset("Cancer Effect Offset", Vector) = (0,0,0,0)
        _CancerEffectRange("Cancer Effect Range", Range(0, 1)) = 1
        [Enum(No,0, Yes,1)] _RemoveCameraRoll("Remove Camera Roll", Int) = 0
        [Enum(No,0, Yes,1)] _FalloffEnabled("Falloff Enabled", Int) = 0
        [Enum(OpacityOnly,1, DistortionOnly,2, OpacityAndDistortion,3)] _FalloffFlags("Falloff Flags", Int) = 3
        _FalloffBeginPercentage("Falloff Begin Percentage", Range(0,100)) = 0.75
        _FalloffEndPercentage("Falloff End Percentage", Range(0,100)) = 1.0
        _FalloffAngleBegin("Falloff Angle Begin", Range(0,1)) = 0.1
        _FalloffAngleEnd("Falloff Angle End", Range(0,1)) = 0.2

        [Enum(No,0, Yes,1)] _ParticleSystem("Particle System", Int) = 0

        // Image Effects
        _MemeTex("Meme Image (RGB)", 2D) = "white" {}
        _MemeImageColumns("Meme Image Columns", Int) = 1
        _MemeImageRows("Meme Image Rows", Int) = 1
        _MemeImageCount("Meme Image Count", Int) = 1
        _MemeImageIndex("Meme Image Index", Int) = 0
        _MemeImageAngle("Meme Image Angle", Float) = 0
        [Enum(Screen,0, Object,1, Screen And Object Direction,2)] _MemeImageAlignment("Meme Image Alignment", Int) = 0
        _MemeImageDistance("Meme Image Distance", Float) = 50
        _MemeImageYaw("Meme Image Yaw", Float) = 0
        _MemeImagePitch("Meme Image Pitch", Float) = 0
        _MemeTexOpacity("Meme Opacity", Float) = 0
        [Enum(No,0, Yes,1)] _MemeTexClamp("Meme Clamp", Int) = 0
        [Enum(No,0, Yes,1)] _MemeTexCutOut("Meme Cut Out", Int) = 0
        _MemeTexAlphaCutOff("Meme Alpha CutOff", Float) = 0.9
        [Enum(None,0, Background,1, Empty Space,2)] _MemeTexOverrideMode("Meme Screen Override Mode", Float) = 0
        [Enum(No,0, Yes (Requires Directional Light),1)] _MemeImageZTest("Meme ZTest", Int) = 0

        // Screen color effects
        [HDR]_ColorMask("Color Mask", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        // Attempt to draw ourselves after all normal avatar and world draws
        // Opaque = 2000, Transparent = 3000, Overlay = 4000
        // Note: As of VRChat 2018 update, object draws are clamped
        //		 to render queue 4000, and particles to 5000.
        Tags
        {
            "Queue" = "Overlay" "IgnoreProjector" = "True" "VRCFallback" = "Hidden"
        }

        // Don't write depth, and ignore the current depth.
        Cull[_CullMode] ZWrite[_ZWrite] ZTest[_ZTest]

        // Grab Pass textures are shared by name, so this must be a unique name.
        // Otherwise we'll get the screen texture from the time the first object rendered
        //
        // Thus when using this shader, or any other public GrabPass based shader,
        // you should use your own name to avoid users being able to break your shader.
        //
        // ex. Rendering an invisible object at render queue '0' to make everyone using
        //	   the label '_backgroundTexture' render nothing.
        //
        // If you would like to layer multiple StereoCancer shaders, then the additional
        // shaders should user their own label otherwise like stated above, you'll get
        // just the original cancer-free texture.
        //
        // Ex. _stereoCancerTexture1, _stereoCancerTexture2
        //
        // Note: If you modify this label, then the following variables will need to be renamed
        //		 along with all of their references to match: 
        //			sampler2D _stereoCancerTexture;
        //			float4 _stereoCancerTexture_TexelSize;

        GrabPass
        {
            "_stereoCancerTexture"
        }

        Pass
        {
            CGPROGRAM
            // Request Shader Model 5.0 to increase our uniform limit.
            // VRChat runs on DirectX 11 so this should be supported by all GPUs.
            #pragma target 5.0

            #pragma vertex vert
            #pragma fragment frag

            // Unity default includes
            #include "UnityCG.cginc"

            // Math Helpers
            #include "CancerHelper.cginc"

            #include "StereoCancerParameters.cginc"

            // Leave only grab pass texture parameters in the main shader file,
            // that way layer creation only needs to parse one file.

            // SPS-I Support
            UNITY_DECLARE_SCREENSPACE_TEXTURE(_stereoCancerTexture);
            float4 _stereoCancerTexture_TexelSize;

            // SPS-I Support
            // For layer support we need to be able to update the texture variable name. This allows me to do this without having to parse the whole functions file too.
            #define SCREEN_SPACE_TEXTURE_NAME _stereoCancerTexture

            // Stereo Cancer function implementations
            #include "StereoCancerFunctions.cginc"
            #include "CSDiscriminate.cginc"

            struct appdata
            {
                float4 vertex : POSITION;

                // For getting particle position and scale
                float4 uv : TEXCOORD0;

                // SPS-I Support
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 viewPos: TEXCOORD1;

                nointerpolation float3 camFront : TEXCOORD2;
                nointerpolation float3 camRight : TEXCOORD3;
                nointerpolation float3 camUp : TEXCOORD4;
                nointerpolation float3 camPos : TEXCOORD5;
                nointerpolation float3 centerCamPos : TEXCOORD6;
                nointerpolation float3 centerCamViewDir : TEXCOORD7;
                nointerpolation float3 objPos : TEXCOORD8;
                nointerpolation float3 screenSpaceObjPos : TEXCOORD9;
                nointerpolation float2 colorDistortionFalloff : TEXCOORD10;

                // SPS-I Support
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert(appdata v)
            {
                v2f o;

                // SPS-I Support
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // Note: This does not utilize cross products to avoid the issue where
                //		 at certain rotations the Up and Right vectors will flip.
                //		 (Roll of +-30 degrees and +-90 degrees).
                o.camFront = normalize(mul((float3x3)unity_CameraToWorld, float3(0, 0, 1)));
                o.camUp = normalize(mul((float3x3)unity_CameraToWorld, float3(0, 1, 0)));
                o.camRight = normalize(mul((float3x3)unity_CameraToWorld, float3(1, 0, 0)));

                // Apparently the built-in _WorldSpaceCameraPos can't be trusted...so manually access the camera position.
                o.camPos = float3(unity_CameraToWorld[0][3], unity_CameraToWorld[1][3], unity_CameraToWorld[2][3]);

                bool inMirror = is_in_mirror();
                bool noRender =
                        _MirrorMode == MIRROR_DISABLE && inMirror
                        || _MirrorMode == MIRROR_ONLY && !inMirror
                        #if defined(USING_STEREO_MATRICES)
                        || _PlatformSelector == PLATFORM_DESKTOP
                        || _EyeSelector == EYE_LEFT && !is_eye(0, inMirror)
                        || _EyeSelector == EYE_RIGHT && !is_eye(1, inMirror)
                        #else
                        || _PlatformSelector == PLATFORM_VR
                    #endif
                    ;


                if (noRender)
                {
                    v.vertex.xyz = 1.0e25;
                    o = (v2f)0;
                    o.pos = UnityObjectToClipPos(v.vertex);
                    return o;
                }

                #if defined(USING_STEREO_MATRICES)
                o.centerCamPos = lerp(
                    float3(unity_StereoCameraToWorld[0][0][3], unity_StereoCameraToWorld[0][1][3],
                           unity_StereoCameraToWorld[0][2][3]),
                    float3(unity_StereoCameraToWorld[1][0][3], unity_StereoCameraToWorld[1][1][3],
                              unity_StereoCameraToWorld[1][2][3]),
                    0.5);

                int otherCameraIndex = 1 - unity_StereoEyeIndex;
                o.centerCamViewDir = lerp(
                    o.camFront, mul((float3x3)unity_StereoCameraToWorld[otherCameraIndex], float3(0, 0, 1)), 0.5);
                o.centerCamViewDir = normalize(o.centerCamViewDir);
                #else
                UNITY_BRANCH
                if (_VRChatMirrorMode > 0)
                {
                    o.centerCamPos = _VRChatMirrorCameraPos;
                }
                else
                {
                    o.centerCamPos = o.camPos;
                }

                // Sorry canted display users, I don't see a way to calculate the proper view direction in the mirror without VRChat adding a center camera view direction.
                o.centerCamViewDir = o.camFront;
                #endif

                // Extract object position from the model matrix.
                o.objPos = float3(UNITY_MATRIX_M[0][3], UNITY_MATRIX_M[1][3], UNITY_MATRIX_M[2][3]);

                // Usage: Set the following Renderer settings for the particle system
                //		  Render Alignment: World
                //		  Custom Vertex Streams:
                //				Position (POSITION.xyz)
                //				Center   (TEXCOORD0.xyz)
                //				Size.x   (TEXCOORD0.w)
                if (_ParticleSystem == 1)
                {
                    o.objPos = v.uv.xyz;
                }

                // Fullscreen
                if (_ObjectDisplayMode == 0)
                {
                    // Place the mesh on the viewer's face, and ensure it covers the entire view
                    // even when the user is looking at a mirror at a near-perpindicular angle.
                    // Note: This won't handle extraordinarily large mirrors, leaving a gap on the sides
                    //		 of what the viewer can see.
                    v.vertex.xyz *= 100;

                    o.viewPos = v.vertex + float4(o.centerCamPos, 0);
                    o.viewPos = mul(UNITY_MATRIX_V, o.viewPos);
                }
                // World Scale
                else
                {
                    o.viewPos = mul(UNITY_MATRIX_MV, v.vertex);
                }

                o.pos = mul(UNITY_MATRIX_P, o.viewPos);

                o.colorDistortionFalloff = float2(1, 1);
                // When enabled, generates falloff values and evicts the vertex to outer-space once falloff reaches zero.
                if (_FalloffEnabled == 1)
                {
                    // For VR we want to use a consistent camera position and direction so that the eyes get the same amount
                    // of opacity and distortion reduction.
                    float distanceFalloffAlpha;

                    // Normal Objects
                    if (_ParticleSystem == 0)
                    {
                        // Handle non-uniform scaling and rotation in one easy step!
                        float3 objSpaceCamPos = abs(mul(unity_WorldToObject, float4(o.centerCamPos, 1)).xyz);

                        distanceFalloffAlpha = max(max(objSpaceCamPos.x, objSpaceCamPos.y), objSpaceCamPos.z);
                    }
                    // Particles
                    else
                    {
                        // Particle model matrix (UNITY_MATRIX_M) doesn't contain scale or translation,
                        // so a spherical distance check will do just fine as a replacement.
                        distanceFalloffAlpha = distance(o.objPos, o.centerCamPos) * (rcp(v.uv.w) * 0.5);
                    }

                    float falloffMin = (0.5 * _FalloffBeginPercentage);
                    float falloffMax = (0.5 * _FalloffEndPercentage);
                    distanceFalloffAlpha = smoothstep(falloffMin, falloffMax, distanceFalloffAlpha);
                    o.colorDistortionFalloff.xy -= distanceFalloffAlpha * float2(
                        (_FalloffFlags & 1) != 0, (_FalloffFlags & 2) != 0);

                    // Angle falloff, basically required for good Centered On Object coordinate space usage.
                    if (_FalloffAngleBegin < 1)
                    {
                        float3 toObjectVec = normalize(o.objPos - o.centerCamPos);
                        float angle = clamp(dot(toObjectVec, o.centerCamViewDir), -1, 1);

                        float angleFalloffBegin = 1 - _FalloffAngleBegin;
                        float angleFalloffEnd = 1 - _FalloffAngleEnd;

                        float angleFalloffAlpha = smoothstep(angleFalloffBegin, angleFalloffEnd, angle);

                        o.colorDistortionFalloff.xy -= angleFalloffAlpha * float2(
                            (_FalloffFlags & 1) != 0, (_FalloffFlags & 2) != 0);
                    }

                    // Ensure we haven't gone negative after applying both types of falloff.
                    o.colorDistortionFalloff.xy = clamp(o.colorDistortionFalloff.xy, 0, 1);

                    // No output, evict mesh to outer-space.
                    if (!any(o.colorDistortionFalloff))
                        o.pos = float4(9999, 9999, 9999, 9999);
                }

                // Evicts the vertex to outer-space when visibility doesn't match the display mode.
                if (mirrorCheck(_CancerDisplayMode))
                    o.pos = float4(9999, 9999, 9999, 9999);

                // Convert object position to screen-space after all coordinate space math
                // is finished.
                o.screenSpaceObjPos = mul(UNITY_MATRIX_V, float4(o.objPos, 1));
                o.screenSpaceObjPos /= o.screenSpaceObjPos.z;

                o.screenSpaceObjPos.xy *= float2(50, -50);

                return o;
            }

            fixed4 frag(v2f i, out float depth : SV_DEPTH) : SV_Target
            {
                // SPS-I Support
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                // VRChat displays nameplates beyond queue 4000 with depth testing enabled,
                // so we can remove them by writting the nearest depth.
                depth = _DisableNameplates ? 1 : i.pos.z;

                // Used for Image Overlay ZTest
                float4 startingViewPos = i.viewPos;

                if (_DisplayOnSurface)
                {
                    // Normally the normalization inverts the coordinates since view-space Z is negative,
                    // so we need to reproduce that here. Additionally, the screen space object position
                    // needs to be scaled by the view position so that when using Centered On Object
                    // coordinates the origin doesn't fly away with view distance.
                    i.viewPos.xyz *= -1;
                    i.screenSpaceObjPos.xy *= i.viewPos.z;
                }
                else
                {
                    // Normalize onto the Z plane to get our 2D coordinates for easy distortion math.
                    i.viewPos.xyz /= i.viewPos.z;
                }

                // The new screen-space coordinate system is backwards and smaller compared to the old
                // system. So in order to prevent breaking all previously made effects we need to
                // invert and scale our coordinates.
                i.viewPos.xyz *= float3(50, -50, -50);

                // Centered On Object coordinate space
                UNITY_BRANCH
                if (_CoordinateSpace == 2)
                    i.viewPos.xy -= i.screenSpaceObjPos.xy;

                // Vector from the 'camera' to the world-axis aligned worldPos.
                float3 worldVector = normalize(i.viewPos);

                // Projected coordinate space
                UNITY_BRANCH
                if (_CoordinateSpace == 1)
                    i.viewPos = projectCoordinates(i.viewPos, i.camPos, worldVector);

                // Allow for easily changing effect intensities without having to modify
                // an entire animation. Also very useful for adjusting projected coordinates.
                i.viewPos.xyz *= _CoordinateScale;

                // Store the starting position to allow for things like using the
                // derivative (ddx, ddy) to calculate nearby positions to sample depth.
                float4 startingAxisAlignedPos = i.viewPos;
                float4 startingWorldPos = computeWorldPositionFromAxisPosition(startingAxisAlignedPos);

                // Quantize the distortion effects separately from the screen
                float3 cancerEffectQuantizationVector = float3(0, 0, 0);
                UNITY_BRANCH
                if (_CancerEffectQuantization != 0)
                {
                    cancerEffectQuantizationVector = i.viewPos.xyz;
                    i.viewPos = stereoQuantization(i.viewPos, 10.0 - _CancerEffectQuantization * 10.0);

                    cancerEffectQuantizationVector = i.viewPos.xyz - cancerEffectQuantizationVector;
                }

                // Rotate the effects separately from the screen
                UNITY_BRANCH
                if (_CancerEffectRotation != 0)
                    i.viewPos.xy = rotate2D(i.viewPos.xy, _CancerEffectRotation);

                // Move the cancer coordiantes separately from the screen
                i.viewPos.xyz += _CancerEffectOffset.xyz;

                // Allow for wrapping the cancer effect coordinates separately from the screen
                float3 cancerEffectWrapVector = float3(0, 0, 0);
                UNITY_BRANCH
                if (_CancerEffectRange != 1)
                {
                    cancerEffectWrapVector = i.viewPos.xyz;

                    float samplingRange = lerp(1.0, _CancerEffectRange, i.colorDistortionFalloff.y);
                    i.viewPos = wrapWorldCoordinates(i.viewPos, samplingRange);

                    cancerEffectWrapVector = i.viewPos.xyz - cancerEffectWrapVector;
                }

                float cameraRollAngle = 0;
                UNITY_BRANCH
                if (_RemoveCameraRoll)
                {
                    // Note: Cancer coordinates will flip upside down when the camera angle beyond 90 degrees up or down.
                    cameraRollAngle = atan2(i.camRight.y, i.camUp.y);

                    i.viewPos.xy = rotate2D(i.viewPos.xy, cameraRollAngle);
                }

                // Allow for functions which create empty space
                bool clearPixel = false;

                // Uniforms (Shader Parameters in Unity) can be branched on to successfully
                // avoid taking the performance hit of unused effects. This is used on every
                // effect with the most intuitive value to automatically improve performance.

                // Note: Not all effects contain all of the final parameters since I don't
                //		 know how many effects I will add yet, and don't want to have to
                //		 remove parameters users are using to make space for effects.

                //////////////////////////////////////////
                // Apply World-Space Distortion Effects //
                //////////////////////////////////////////

                // Shift world pos back from its current axis-aligned position to
                // the position it should be in-front of the camera.
                float4 worldCoordinates = computeWorldPositionFromAxisPosition(i.viewPos);

                // Finally acquire our stereo position with which we can sample the screen texture.
                float4 stereoPosition = computeStereoUV(worldCoordinates);

                // Wrap world coordinates after all effects have been applied
                // This allows for hiding the VR Mask when wrapping around
                //
                // Todo: Grab the frustum corners to calculate the starting
                //		 wrap value.

                if (_WorldSamplingRange != 1)
                {
                    float samplingRange = lerp(1.0, _WorldSamplingRange, i.colorDistortionFalloff.y);

                    // Wrap
                    if (_WorldSamplingMode == 0)
                    {
                        i.viewPos = wrapWorldCoordinates(i.viewPos, samplingRange);

                        worldCoordinates = computeWorldPositionFromAxisPosition(i.viewPos);

                        stereoPosition = computeStereoUV(worldCoordinates);
                    }
                    // Cutout
                    else if (_WorldSamplingMode == 1)
                    {
                        float sampleLimit = samplingRange * 100;
                        sampleLimit -= (abs(i.viewPos.z - 100) / 100) * sampleLimit;
                        sampleLimit = abs(sampleLimit);

                        if (i.viewPos.x < -sampleLimit || i.viewPos.x > sampleLimit ||
                            i.viewPos.y < -sampleLimit || i.viewPos.y > sampleLimit)
                            discard;
                    }
                    // Clamp
                    else if (_WorldSamplingMode == 2)
                    {
                        float sampleLimit = samplingRange * 100;
                        sampleLimit -= (abs(i.viewPos.z - 100) / 100) * sampleLimit;
                        sampleLimit = abs(sampleLimit);

                        i.viewPos.xy = clamp(i.viewPos.xy, -sampleLimit, sampleLimit);

                        // Update world pos to match our new modified world axis position.
                        worldCoordinates = computeWorldPositionFromAxisPosition(i.viewPos);

                        stereoPosition = computeStereoUV(worldCoordinates);
                    }
                    // Empty Space
                    else if (_WorldSamplingMode == 3)
                    {
                        float sampleLimit = samplingRange * 100;
                        sampleLimit -= (abs(i.viewPos.z - 100) / 100) * sampleLimit;
                        sampleLimit = abs(sampleLimit);

                        if (i.viewPos.x < -sampleLimit || i.viewPos.x > sampleLimit
                            || i.viewPos.y < -sampleLimit || i.viewPos.y > sampleLimit)
                        {
                            clearPixel = true;
                        }
                    }
                }

                // Apply falloff to distortion
                UNITY_BRANCH
                if (i.colorDistortionFalloff.y < 1)
                {
                    i.viewPos.xyz = lerp(startingAxisAlignedPos.xyz, i.viewPos.xyz, i.colorDistortionFalloff.y);

                    worldCoordinates = lerp(startingWorldPos, worldCoordinates, i.colorDistortionFalloff.y);
                    stereoPosition = computeStereoUV(worldCoordinates);
                }

                // Undo the camera roll removal, cancer effect offset, rotation, and quantization for ONLY the screen sample coordinates
                // This allows for moving effects around without affecting the screen.
                // Ex. Meme spotlight movement via Vignette 
                float4 originalViewPos = i.viewPos;

                UNITY_BRANCH
                if (_RemoveCameraRoll)
                {
                    i.viewPos.xy = rotate2D(i.viewPos.xy, -cameraRollAngle * i.colorDistortionFalloff.y);

                    worldCoordinates = computeWorldPositionFromAxisPosition(i.viewPos);
                    stereoPosition = computeStereoUV(worldCoordinates);
                }

                UNITY_BRANCH
                if (any(_CancerEffectOffset.xyz) || _CancerEffectRotation != 0 || _CancerEffectRange != 1.f)
                {
                    i.viewPos.xyz -= cancerEffectWrapVector * i.colorDistortionFalloff.y;

                    i.viewPos.xyz -= _CancerEffectOffset.xyz * i.colorDistortionFalloff.y;
                    i.viewPos.xy = rotate2D(i.viewPos.xy, -_CancerEffectRotation);

                    float4 temp = computeWorldPositionFromAxisPosition(i.viewPos);
                    stereoPosition = computeStereoUV(temp);
                }

                UNITY_BRANCH
                if (_CancerEffectQuantization != 0)
                {
                    i.viewPos.xyz -= cancerEffectQuantizationVector * i.colorDistortionFalloff.y;

                    float4 temp = computeWorldPositionFromAxisPosition(i.viewPos);
                    stereoPosition = computeStereoUV(temp);
                }

                // Centered On Object coordinate space
                UNITY_BRANCH
                if (_CoordinateSpace == 2)
                {
                    i.viewPos.xy += i.screenSpaceObjPos.xy * _CoordinateScale * i.colorDistortionFalloff.y;

                    worldCoordinates = computeWorldPositionFromAxisPosition(i.viewPos);
                    stereoPosition = computeStereoUV(worldCoordinates);

                    i.camFront = normalize(i.objPos - i.centerCamPos);
                }

                i.viewPos = originalViewPos;

                // Default UV clamping works for desktop, but for VR
                // we may want to constrain UV coordinates to
                // each eye.
                UNITY_BRANCH
                if (_ScreenSamplingMode == 1)
                    stereoPosition = clampUVCoordinates(stereoPosition);
                    // Wrapping allows for creating 'infinite' texture
                    // and tunnel effects.
                else if (_ScreenSamplingMode == 2)
                    stereoPosition = wrapUVCoordinates(stereoPosition);

                /////////////////////////
                // Apply Color Effects //
                /////////////////////////

                half4 bgcolor = half4(0, 0, 0, 0);

                bgcolor = UNITY_SAMPLE_SCREENSPACE_TEXTURE(SCREEN_SPACE_TEXTURE_NAME,
  stereoPosition.xy / stereoPosition.w);

                // Ensure pure black is not captured, which ruins image blending and other effects
                // such as value adjustment
                bgcolor.rgb += 0.00000001;

                UNITY_BRANCH
                if (_MemeTexOpacity != 0)
                {
                    float3 planeNormal = i.centerCamViewDir;
                    float3 planeUpVector = i.camUp;
                    float3 planeOrigin = i.centerCamPos + i.centerCamViewDir * _MemeImageDistance;

                    // Object
                    if (_MemeImageAlignment >= 1)
                    {
                        planeNormal = normalize(mul((float3x3)UNITY_MATRIX_M, float3(0, 0, 1)));
                        planeUpVector = normalize(mul((float3x3)UNITY_MATRIX_M, float3(0, 1, 0)));
                        planeOrigin = _MemeImageAlignment == 2 ? i.centerCamPos : i.objPos;
                        planeOrigin += planeNormal * _MemeImageDistance;
                    }
                    if (_MemeImageYaw != 0.0)
                    {
                        planeNormal = mul(rotAxis(planeUpVector, _MemeImageYaw), planeNormal);
                    }
                    if (_MemeImagePitch != 0.0)
                    {
                        planeNormal = mul(rotAxis(normalize(cross(planeUpVector, planeNormal)), _MemeImagePitch),
                 planeNormal);
                    }

                    // Projected
                    if (_CoordinateSpace == 1)
                    {
                        planeOrigin -= i.viewPos.z * i.centerCamViewDir;
                    }
                    // Centered On Object
                    else if (_CoordinateSpace == 2)
                    {
                        planeOrigin += (i.objPos - i.centerCamPos);
                    }

                    float3 pixelDir = worldCoordinates.xyz;
                    // Screen
                    if (_MemeImageAlignment == 0 && _RemoveCameraRoll == 1)
                    {
                        pixelDir -= i.centerCamPos;
                        pixelDir = mul(rotAxis(i.centerCamViewDir, cameraRollAngle), pixelDir);
                        pixelDir += i.centerCamPos;
                    }
                    pixelDir = normalize(pixelDir - i.camPos);

                    const float planeIntersectionDistance =
                        intersectPlane(planeOrigin, planeNormal, i.camPos, pixelDir);
                    const float3 planeIntersectionPoint = (i.camPos + pixelDir * planeIntersectionDistance);
                    const float3 positionOnPlane = planeIntersectionPoint - planeOrigin;

                    float4 samplePosition = float4(0, 0, 0, 0);

                    // https://math.stackexchange.com/questions/3528493/convert-3d-point-onto-a-2d-coordinate-plane-of-any-angle-and-location-within-the
                    const float3 planeUAxis = normalize(cross(-planeUpVector, planeNormal));
                    const float3 planeVAxis = normalize(cross(planeUAxis, planeNormal));

                    // Need to determine the UV axis we can use which doesn't align with the world axis to avoid dividing by zero.
                    const float denominators[3] = {
                        planeUAxis.x * planeVAxis.y - planeVAxis.x * planeUAxis.y,
                        planeUAxis.x * planeVAxis.z - planeVAxis.x * planeUAxis.z,
                        planeUAxis.y * planeVAxis.z - planeVAxis.y * planeUAxis.z
                    };

                    int UIndex = 0;
                    if (abs(denominators[UIndex]) < 0.01)
                        UIndex++;
                    if (abs(denominators[UIndex]) < 0.01)
                        UIndex++;

                    switch (UIndex)
                    {
                    case 0:
                        samplePosition.x = positionOnPlane.x * planeVAxis.y - positionOnPlane.y * planeVAxis.x;
                        samplePosition.y = positionOnPlane.y * planeUAxis.x - positionOnPlane.x * planeUAxis.y;
                        break;
                    case 1:
                        samplePosition.x = positionOnPlane.x * planeVAxis.z - positionOnPlane.z * planeVAxis.x;
                        samplePosition.y = positionOnPlane.z * planeUAxis.x - positionOnPlane.x * planeUAxis.z;
                        break;
                    case 2:
                        samplePosition.x = positionOnPlane.y * planeVAxis.z - positionOnPlane.z * planeVAxis.y;
                        samplePosition.y = positionOnPlane.z * planeUAxis.y - positionOnPlane.y * planeUAxis.z;
                        break;
                    }

                    samplePosition.xy /= denominators[UIndex];

                    // Flip every other rotation so the image stays facing the same vertical direction. Horizontal flip is handled by the plane itself.
                    samplePosition.y *= -1 + 2 * (abs(fmod(-abs(_MemeImagePitch) - UNITY_HALF_PI, UNITY_TWO_PI)) <
                        UNITY_PI);

                    if (_MemeImageAngle != 0)
                        samplePosition.xy = rotate2D(samplePosition.xy, _MemeImageAngle);

                    bool dropMemePixels = false;
                    half4 memeColor = stereoImageOverlay(samplePosition, startingAxisAlignedPos,
                                     _MemeTex, _MemeTex_ST, _MemeTex_TexelSize,
                                     _MemeImageColumns, _MemeImageRows, _MemeImageCount,
                                     _MemeImageIndex,
                                     _MemeTexClamp, _MemeTexCutOut,
                                     dropMemePixels);

                    // Hide the plane on the other side of the camera, while allowing for displaying the backface of the plane.
                    dropMemePixels = dropMemePixels || planeIntersectionDistance < 0;

                    if (_MemeImageZTest == 1)
                    {
                        float4 cullWorldPos = worldCoordinates;

                        // Since the distortion isn't applied to the screen in this case, use the original pixel for culling.
                        // This allows for making the distorted image appear like it is a normal mesh in the world.
                        // Override Background
                        if (_MemeTexOverrideMode == 1)
                        {
                            cullWorldPos = mul(UNITY_MATRIX_I_V, startingViewPos);
                        }

                        const float3 projectedWorldCoordinates = worldPosFromDepth(
                            computeStereoUV(cullWorldPos), i.camPos, cullWorldPos);
                        dropMemePixels = dropMemePixels || (length(projectedWorldCoordinates - i.camPos) <
                            planeIntersectionDistance);
                    }

                    if (dropMemePixels == false)
                    {
                        if (memeColor.a > _MemeTexAlphaCutOff)
                        {
                            // No override mode, blend image in.
                            if (_MemeTexOverrideMode == 0)
                            {
                                bgcolor.rgb = lerp(bgcolor.rgb, memeColor.rgb, (_MemeTexOpacity * memeColor.a));
                            }
                            // Override Background
                            else if (_MemeTexOverrideMode == 1)
                            {
                                bgcolor = float4(memeColor.rgb * (_MemeTexOpacity * memeColor.a), 1);
                            }
                            // Override Empty Space
                            else if (_MemeTexOverrideMode == 2)
                            {
                                if (clearPixel)
                                {
                                    bgcolor = float4(memeColor.rgb * (_MemeTexOpacity * memeColor.a), 1);
                                    return bgcolor;
                                }
                            }
                        }
                        // Overriding background but pixel has been cutout.
                        else if (_MemeTexOverrideMode == 1)
                            discard;
                    }
                    else
                    {
                        // Override Background
                        if (_MemeTexOverrideMode == 1)
                            discard;
                    }
                }

                bgcolor *= _ColorMask;

                // Allow the user to fade the cancer shader effects in and out
                // as well as do blending shenanigans
                // e.g. Negative or large positive values, layering effects, etc
                //
                // Usage example: 'Cursed' graphics
                //				 _CancerOpacity = -45.00 
                //
                //				 _SkewXDistance = 15.00
                //				 _SkewXInterval = 2.8
                //
                //				_BarXDistance = 10.00
                //				_BarXInterval = 18.00

                // Apply falloff to color
                bgcolor.a = _CancerOpacity * i.colorDistortionFalloff.x;

                // I'm sorry fellow VRChat players, but you've just contracted eye-cancer.
                //	-xwidghet
                return bgcolor;
            }
            ENDCG
        }
    }
}