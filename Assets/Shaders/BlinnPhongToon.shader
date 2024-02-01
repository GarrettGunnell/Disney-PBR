Shader "Acerola/BlinnPhong" {

    Properties {
        _AlbedoTex ("Albedo", 2D) = "" {}
        _NormalTex ("Normal", 2D) = "" {}
        _NormalStrength ("Normal Strength", Range(0.0, 3.0)) = 1.0
        _ShininessTex ("Shininess", 2D) = "" {}
        _DirectSpecularPeak ("Specular Peak", Range(0.0, 200.0)) = 20.0
        _SpecularStrength ("Specular Strength", Range(0.0, 2.0)) = 1.0
        _F0 ("Direct Fresnel", Range(0.0, 2.0)) = 0.028
        _SkyboxCube ("Skybox", Cube) = "" {}
        _IndirectSpecularPeak ("Indirect Specular Peak", Range(0.0, 100.0)) = 20.0
        _IndirectSpecularStrength ("Indirect Specular Strength", Range(0.0, 2.0)) = 1.0
        _F1 ("Indirect Fresnel", Range(0.0, 2.0)) = 0.028
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

            sampler2D _AlbedoTex, _NormalTex, _ShininessTex;
            samplerCUBE _SkyboxCube;
            float _NormalStrength, _DirectSpecularPeak, _IndirectSpecularPeak, _SpecularStrength, _IndirectSpecularStrength, _F0, _F1;

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

                float3 ndotl = _LightColor0 * DotClamped(_WorldSpaceLightPos0.xyz, normal);

                float shadow = SHADOW_ATTENUATION(i);

                float3 lightDir = normalize(_WorldSpaceLightPos0 - i.worldPos);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 halfwayDir = normalize(_WorldSpaceLightPos0 + viewDir);
                float3 reflectedDir = reflect(-viewDir, normal);

                float base = 1 - dot(viewDir, halfwayDir);
                float exponential = pow(base, 5.0f);
                float fresnel = exponential + (_F0) * (1.0f - exponential);

                float shininess = saturate(tex2D(_ShininessTex, uv).r * 2.0f);
                float spec = pow(DotClamped(normal, halfwayDir), _DirectSpecularPeak) * shininess;
                spec *= fresnel;

                float3 directDiffuse = albedo;
                float3 directSpecular = _LightColor0 * saturate(spec * _SpecularStrength);
                float3 directLight = (directDiffuse + directSpecular) * ndotl * shadow;

                float3 indirectDiffuse = albedo * texCUBElod(_SkyboxCube, float4(normal, 5)).rgb * 1.0f;

                float indirectSpec = pow(DotClamped(normal, normalize(normal - viewDir)), _IndirectSpecularPeak) * (shininess);
                float indirectFresnel = exponential + _F1 * (1.0f - exponential);

                float3 indirectSpecular = texCUBElod(_SkyboxCube, float4(reflectedDir, 0)).rgb * indirectFresnel * indirectSpec * _IndirectSpecularStrength;
                float3 indirectLight = indirectDiffuse + indirectSpecular;

                return float4(directLight + indirectLight, 1.0f);
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