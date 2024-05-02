Shader "Acerola/Disney" {

    Properties {
        _AlbedoTex ("Albedo", 2D) = "" {}
        _NormalTex ("Normal", 2D) = "" {}
        _NormalStrength ("Normal Strength", Range(0.0, 3.0)) = 1.0
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.4
    }

    SubShader {

        Pass {
            Tags {
                "RenderType" = "Opaque"
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM

            #pragma vertex vp
            #pragma fragment fp

            #pragma multi_compile _ SHADOWS_SCREEN

            #include "UnityPBSLighting.cginc"
            #include "AutoLight.cginc"

            #define PI 3.14159265f

            sampler2D _AlbedoTex, _NormalTex;
            float _NormalStrength, _Roughness;

            struct VertexData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vp(VertexData v) {
                v2f i;
                i.pos = UnityObjectToClipPos(v.vertex);
                i.worldPos = mul(unity_ObjectToWorld, v.vertex);
                i.normal = UnityObjectToWorldNormal(v.normal);
                i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
                i.uv = v.uv;
                TRANSFER_SHADOW(i);

                return i;
            }

            float SchlickFresnel(float x) {
                return pow(saturate(1 - x), 5);
            }

            float4 fp(v2f i) : SV_TARGET {
                float2 uv = i.uv;
                float3 albedo = tex2D(_AlbedoTex, uv).rgb;
                
                // Unpack DXT5nm tangent space normal
                float3 N;
                N.xy = tex2D(_NormalTex, uv).wy * 2 - 1;
                N.xy *= _NormalStrength;
                N.z = sqrt(1 - saturate(dot(N.xy, N.xy)));
                float3 tangentSpaceNormal = N;
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;
                N = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);

                float3 L = _WorldSpaceLightPos0.xyz; // Direction to light source
                float3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz); // Direction to camera
                float3 H = normalize(L + V); // Microfacet normal of perfect reflection
                float3 R = normalize(reflect(-V, N)); // Direction of reflection across normal from viewer

                float ndotl = DotClamped(N, L);
                float ndotv = DotClamped(N, V);
                float ndoth = DotClamped(N, H);
                float ldoth = DotClamped(L, H);
                float vdoth = DotClamped(V, H);

                float FD90 = 0.5f + 2.0f * _Roughness * ldoth * ldoth;

                float F = lerp(1.0f, FD90, SchlickFresnel(ndotl)) * lerp(1.0f, FD90, SchlickFresnel(ndotv));

                float3 diffuse = (albedo / PI) * F;

                // Distribution

                float alpha = _Roughness * _Roughness;

                float GTRdenom = 1.0f + (alpha * alpha - 1) * ndoth * ndoth;
                float GTR = (alpha * alpha) / (PI * GTRdenom * GTRdenom);

                float F0 = 0.1f;
                float Fspec = lerp(F0, 1.0f, SchlickFresnel(ldoth));

                return Fspec;

                float shadow = SHADOW_ATTENUATION(i);

                float3 output = diffuse * ndotl * shadow;

                return float4(output, 1.0f);
            }

            ENDCG
        }

        Pass {
            Tags {
            "LightMode" = "ShadowCaster"
            }

            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            #include "UnityCG.cginc"

            struct VertexData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
            };

            v2f vp(VertexData v) {
                v2f o;

                o.pos = UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normal);
                o.pos = UnityApplyLinearShadowBias(o.pos);

                return o;
            }

            float4 fp(v2f i) : SV_Target {
                return 0;
            }

            ENDCG
        }
    }
}