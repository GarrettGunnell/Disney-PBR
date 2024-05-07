Shader "Acerola/LambertianDiffuse" {

    Properties {
        _AlbedoTex ("Albedo", 2D) = "" {}
        _NormalTex ("Normal", 2D) = "" {}
        _NormalStrength ("Normal Strength", Range(0.0, 3.0)) = 1.0
        _SkyboxCube ("Skybox", Cube) = "" {}
    }

    SubShader {

        CGINCLUDE

        #include "UnityPBSLighting.cginc"
        #include "AutoLight.cginc"

        samplerCUBE _SkyboxCube;
        sampler2D _AlbedoTex, _NormalTex;
        float _NormalStrength;

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

        ENDCG

        Pass {
            Tags {
                "RenderType" = "Opaque"
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM

            #pragma vertex vp
            #pragma fragment fp

            #pragma multi_compile _ SHADOWS_SCREEN

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

            float4 fp(v2f i) : SV_TARGET {
                float2 uv = i.uv;
                float3 albedo = tex2D(_AlbedoTex, uv).rgb;
                
                // Unpack DXT5nm tangent space normal
                float3 normal;
                normal.xy = tex2D(_NormalTex, uv).wy * 2 - 1;
                normal.xy *= _NormalStrength;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
                float3 tangentSpaceNormal = normal;
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;
                normal = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);

                float ndotl = DotClamped(_WorldSpaceLightPos0.xyz, normal);

                float shadow = SHADOW_ATTENUATION(i);

                float3 directDiffuse = _LightColor0 * albedo * ndotl * shadow;

                float3 indirectLight = texCUBElod(_SkyboxCube, float4(normal, 5)).rgb;
                float3 indirectDiffuse = albedo * indirectLight;

                return float4(directDiffuse + indirectDiffuse, 1.0f);
            }

            ENDCG
        }

        Pass {
            Tags {
                "LightMode" = "ForwardAdd"
            }

            Blend One One

            CGPROGRAM

            #pragma vertex vp
            #pragma fragment fp

            #pragma multi_compile _ SHADOWS_SCREEN

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

            float4 fp(v2f i) : SV_TARGET {
                float2 uv = i.uv;
                float3 col = tex2D(_AlbedoTex, uv).rgb;
                
                // Unpack DXT5nm tangent space normal
                float3 normal;
                normal.xy = tex2D(_NormalTex, uv).wy * 2 - 1;
                normal.xy *= _NormalStrength;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
                float3 tangentSpaceNormal = normal;
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;
                normal = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);

                float ndotl = DotClamped(_WorldSpaceLightPos0.xyz, normal);

                return float4(_LightColor0 * col * ndotl, 1.0f);
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

            struct ShadowVertexData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct Shadowv2f {
                float4 pos : SV_POSITION;
            };

            Shadowv2f vp(ShadowVertexData v) {
                Shadowv2f o;

                o.pos = UnityClipSpaceShadowCasterPos(v.vertex.xyz, v.normal);
                o.pos = UnityApplyLinearShadowBias(o.pos);

                return o;
            }

            float4 fp(Shadowv2f i) : SV_Target {
                return 0;
            }

            ENDCG
        }
    }
}