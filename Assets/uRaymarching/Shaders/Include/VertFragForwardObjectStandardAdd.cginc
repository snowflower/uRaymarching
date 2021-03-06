﻿#ifndef VERT_FRAG_FORWARD_OBJECT_STANDARD_ADD_H
#define VERT_FRAG_FORWARD_OBJECT_STANDARD_ADD_H

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

#include "./Structs.cginc"
#include "./Raymarching.cginc"
#include "./Utils.cginc"

float _MinDistance;
int _Loop;
fixed4 _Color;
float _Glossiness;
float _Metallic;

struct VertOutput
{
    UNITY_POSITION(pos);
    float4 projPos : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    float3 worldNormal : TEXCOORD2;
    UNITY_SHADOW_COORDS(3)
    UNITY_FOG_COORDS(4)
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

VertOutput Vert(appdata_full v)
{
    VertOutput o;
    UNITY_INITIALIZE_OUTPUT(VertOutput, o);

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v,o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    o.pos = UnityObjectToClipPos(v.vertex);
    o.projPos = ComputeScreenPos(o.pos);
    COMPUTE_EYEDEPTH(o.projPos.z);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.worldNormal = UnityObjectToWorldNormal(v.normal);

    UNITY_TRANSFER_SHADOW(o,v.texcoord1.xy);
    UNITY_TRANSFER_FOG(o,o.pos);
    return o;
}

float4 Frag(VertOutput i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(IN);

    RaymarchInfo ray;
    UNITY_INITIALIZE_OUTPUT(RaymarchInfo, ray);
    ray.rayDir = normalize(i.worldPos - GetCameraPosition());
    ray.startPos = i.worldPos;

#ifdef CAMERA_INSIDE_OBJECT
    float3 startPos = GetCameraPosition() + (GetCameraNearClip() + 0.01) * ray.rayDir;
    if (IsInnerObject(startPos)) {
        ray.startPos = startPos;
    }
#endif

    ray.polyNormal = i.worldNormal;
    ray.minDistance = _MinDistance;
#ifdef USE_CAMERA_DEPTH_TEXTURE
    ray.maxDistance = GetMaxDistanceFromDepthTexture(i.projPos, ray.rayDir);
#else
    ray.maxDistance = GetCameraFarClip();
#endif
    ray.maxLoop = _Loop;

    Raymarch(ray);

    float3 worldPos = ray.endPos;
    float3 worldNormal = 2.0 * ray.normal - 1.0;
    fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
#ifdef USING_DIRECTIONAL_LIGHT
    fixed3 lightDir = _WorldSpaceLightPos0.xyz;
#else
    fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
#endif

    SurfaceOutputStandard so;
    UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, so);
    so.Albedo = _Color.rgb;
    so.Metallic = _Metallic;
    so.Smoothness = _Glossiness;
    so.Emission = 0.0;
    so.Alpha = _Color.a;
    so.Occlusion = 1.0;
    so.Normal = worldNormal;

#ifdef POST_EFFECT
    POST_EFFECT(ray, so);
#endif

    UNITY_LIGHT_ATTENUATION(atten, i, worldPos)

    UnityGI gi;
    UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
    gi.indirect.diffuse = 0;
    gi.indirect.specular = 0;
    gi.light.color = _LightColor0.rgb;
    gi.light.dir = lightDir;
    gi.light.color *= atten;

    float4 c = 0;
    c += LightingStandard(so, worldViewDir, gi);
    c.a = 0.0;

    UNITY_APPLY_FOG(i.fogCoord, c);
    UNITY_OPAQUE_ALPHA(c.a);

    return c;
}

#endif
