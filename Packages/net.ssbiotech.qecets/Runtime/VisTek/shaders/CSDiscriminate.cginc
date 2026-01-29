#ifndef CS_DISCRIMINATE_CGINC
#define CS_DISCRIMINATE_CGINC

#define MIRROR_NORMAL 0
#define MIRROR_DISABLE 1
#define MIRROR_ONLY 2

#define EYE_BOTH 0
#define EYE_LEFT 1
#define EYE_RIGHT 2

#define PLATFORM_ALL 0
#define PLATFORM_DESKTOP 1
#define PLATFORM_VR 2

bool is_in_mirror()
{
    return unity_CameraProjection[2][0] != 0 || unity_CameraProjection[2][1] != 0;
}

bool is_eye(int eye_index, bool mirror)
{
    return (mirror ? UNITY_MATRIX_P._13 >= 0 : unity_StereoEyeIndex) == eye_index;
}

#endif
