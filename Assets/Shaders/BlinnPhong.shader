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

        CGINCLUDE
    
        #include "UnityPBSLighting.cginc"
        #include "AutoLight.cginc"

        #define PI 3.14159265f


        float SchlickFresnel(float x) {
            x = saturate(1.0f - x);
            float x2 = x * x;

            return x2 * x2 * x; // While this is equivalent to pow(1 - x, 5) it is two less mult instructions
        }

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
            float3 objectPos : TEXCOORD4;
            SHADOW_COORDS(5)
        };

        struct BRDFResults {
          float3 diffuse;
          float3 specular;  
        };

        BRDFResults BlinnPhongBRDF(float3 L, float3 V, float3 N) {
            BRDFResults output;
            output.diffuse = 0.0f;
            output.specular = 0.0f;

            float3 H = normalize(L + V);
            float3 R = reflect(-V, N);

            float ndotl = DotClamped(N, L);

            float F = lerp(_F0, 1.0f, SchlickFresnel(DotClamped(L, H)));

            float spec = pow(DotClamped(N, H), _DirectSpecularPeak);
            spec *= F;

            output.diffuse = 1 - F;
            output.specular = saturate(spec * _SpecularStrength);

            return output;

            // float3 indirectDiffuse = albedo * texCUBElod(_SkyboxCube, float4(N, 5)).rgb * 1.0f;


            // float3 indirectSpecular = texCUBElod(_SkyboxCube, float4(R, 0)).rgb * _IndirectSpecularStrength;
            // float3 indirectLight = indirectDiffuse + indirectSpecular;

        }

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
                i.objectPos = v.vertex;
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
                float3 N;
                N.xy = tex2D(_NormalTex, uv).wy * 2 - 1;
                N.xy *= _NormalStrength;
                N.z = sqrt(1 - saturate(dot(N.xy, N.xy)));
                float3 tangentSpaceNormal = N;
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;
                N = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);

                float shadow = SHADOW_ATTENUATION(i);

                float3 L = _WorldSpaceLightPos0.xyz;
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                BRDFResults reflection = BlinnPhongBRDF(L, V, N);

                float3 output = _LightColor0 * (reflection.diffuse * albedo + reflection.specular);
                output *= DotClamped(L, N);

                return float4(output, 1.0f);
            }

            ENDCG
        }

        Pass {
            Tags {
                "RenderType" = "Opaque"
                "LightMode" = "ForwardAdd"
            }

            Blend One One
            ZWrite Off

            CGPROGRAM

            #pragma vertex vp
            #pragma fragment fp

            #pragma multi_compile _ SHADOWS_SCREEN


            v2f vp(VertexData v) {
                v2f i;
                i.pos = UnityObjectToClipPos(v.vertex);
                i.worldPos = mul(unity_ObjectToWorld, v.vertex);
                i.objectPos = v.vertex;
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
                float3 N;
                N.xy = tex2D(_NormalTex, uv).wy * 2 - 1;
                N.xy *= _NormalStrength;
                N.z = sqrt(1 - saturate(dot(N.xy, N.xy)));
                float3 tangentSpaceNormal = N;
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;
                N = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);

                float3 L = _WorldSpaceLightPos0.xyz;
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                BRDFResults reflection = BlinnPhongBRDF(L, V, N);

                float3 output = _LightColor0 * (reflection.diffuse * albedo + reflection.specular);
                output *= DotClamped(L, N);

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