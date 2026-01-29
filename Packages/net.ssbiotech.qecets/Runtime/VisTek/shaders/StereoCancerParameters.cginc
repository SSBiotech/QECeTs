#ifndef STEREO_CANCER_PARAMETERS
#define STEREO_CANCER_PARAMETERS

// VRChat-Specific global shader uniforms.
// https://docs.vrchat.com/docs/vrchat-202231
float _VRChatCameraMode;
float _VRChatMirrorMode;
float3 _VRChatMirrorCameraPos;

int _ParticleSystem;
int _DisableNameplates;
float _CoordinateSpace;
float _CoordinateScale;
float _WorldSamplingMode;
float _WorldSamplingRange;
float _CancerEffectQuantization;
float _CancerEffectRotation;
float4 _CancerEffectOffset;
float _CancerEffectRange;
int _RemoveCameraRoll;
int _FalloffEnabled;
int _FalloffFlags;
float _FalloffBeginPercentage;
float _FalloffEndPercentage;
float _FalloffAngleBegin;
float _FalloffAngleEnd;
int _MirrorMode;
int _EyeSelector;
int _PlatformSelector;

// Image Overlay params
sampler2D _MemeTex;
float4 _MemeTex_TexelSize;
float4 _MemeTex_ST;
int _MemeImageColumns;
int _MemeImageRows;
int _MemeImageCount;
int _MemeImageIndex;
float _MemeImageDistance;
int _MemeImageAlignment;
float _MemeImagePitch;
float _MemeImageYaw;
float _MemeImageAngle;
float _MemeTexOpacity;
int _MemeTexClamp;
int _MemeTexCutOut;
float _MemeTexAlphaCutOff;
float _MemeTexOverrideMode;
int _MemeImageZTest;

// SPS-I Support
UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
float4 _CameraDepthTexture_TexelSize;

float _CancerOpacity;

// Screen color params
float4 _ColorMask;

// For some magic reason, these have to be down here or the shader explodes.
float _CancerDisplayMode;
float _DisplayOnSurface;
float _ObjectDisplayMode;
float _ScreenSamplingMode;

#endif
