Shader "Acerola/Disney" {

    Properties {
        _AlbedoTex ("Albedo", 2D) = "" {}
        _NormalTex ("Normal", 2D) = "" {}
        _NormalStrength ("Normal Strength", Range(0.0, 3.0)) = 1.0
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0
        _Subsurface ("Subsurface", Range(0.0, 1.0)) = 0
        _Specular ("Specular", Range(0.0, 1.0)) = 0.5
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.5
        _SpecularTint ("Specular Tint", Range(0.0, 1.0)) = 0.0
        _Anisotropic ("Anisotropic", Range(0.0, 1.0)) = 0.0
        _Sheen ("Sheen", Range(0.0, 1.0)) = 0.0
        _SheenTint ("Sheen Tint", Range(0.0, 1.0)) = 0.5
        _ClearCoat ("Clear Coat", Range(0.0, 1.0)) = 0.0
        _ClearCoatGloss ("Clear Coat Gloss", Range(0.0, 1.0)) = 1.0
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
            float _NormalStrength, _Roughness, _Metallic, _Subsurface, _Specular, _SpecularTint, _Anisotropic, _Sheen, _SheenTint, _ClearCoat, _ClearCoatGloss;

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

            float sqr(float x) { 
                return x * x; 
            }

            float luminance(float3 color) {
                return dot(color, float3(0.299f, 0.587f, 0.114f));
            }

            float SchlickFresnel(float x) {
                x = saturate(1.0f - x);
                float x2 = x * x;

                return x2 * x2 * x; // While this is equivalent to pow(1 - x, 5) it is two less mult instructions
            }

            float GGX(float alphaSquared, float ndoth) {
                float b = ((alphaSquared - 1.0f) * ndoth * ndoth + 1.0f);
                return alphaSquared / (PI * b * b);
            }

            float AnisotropicGTR2(float ndoth, float hdotx, float hdoty, float ax, float ay) {
                return rcp(PI * ax * ay * sqr(sqr(hdotx / ax) + sqr(hdoty / ay) + sqr(ndoth)));
            }

            float SmithGGX(float alphaSquared, float ndotl, float ndotv) {
                float a = ndotv * sqrt(alphaSquared + ndotl * (ndotl - alphaSquared * ndotl));
                float b = ndotl * sqrt(alphaSquared + ndotv * (ndotv - alphaSquared * ndotv));

                return 0.5f / (a + b);
            }

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
                float3 albedo = tex2D(_AlbedoTex, uv).rgb * (1 - _Metallic);
                
                // Unpack DXT5nm tangent space normal
                float3 N;
                N.xy = tex2D(_NormalTex, uv).wy * 2 - 1;
                N.xy *= _NormalStrength;
                N.z = sqrt(1 - saturate(dot(N.xy, N.xy)));
                float3 tangentSpaceNormal = N;
                float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w;
                N = normalize(tangentSpaceNormal.x * i.tangent + tangentSpaceNormal.y * binormal + tangentSpaceNormal.z * i.normal);

                float3 L = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.worldPos.xyz, _WorldSpaceLightPos0.w));
                float3 V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz); // Direction to camera
                float3 H = normalize(L + V); // Microfacet normal of perfect reflection
                float3 R = normalize(reflect(-V, N)); // Direction of reflection across normal from viewer
                float3 X = normalize(i.tangent.xyz);
                float3 Y = binormal;

                // N = normalize(i.normal);

                float ndotl = DotClamped(N, L);
                float ndotv = DotClamped(N, V);
                float ndoth = DotClamped(N, H);
                float ldoth = DotClamped(L, H);
                float vdoth = DotClamped(V, H);
                float ldotv = DotClamped(L, V);
                float rdotv = DotClamped(R, V);

                // Disney Diffuse
                float FL = SchlickFresnel(ndotl);
                float FV = SchlickFresnel(ndotv);

                float Fss90 = ldoth * ldoth * _Roughness;
                float Fd90 = 0.5f + 2.0f * Fss90;

                float Fd = lerp(1.0f, Fd90, FL) * lerp(1.0f, Fd90, FV);

                // Subsurface Diffuse (Hanrahan-Krueger brdf approximation)

                float Fss = lerp(1.0f, Fss90, FL) * lerp(1.0f, Fss90, FV);
                float ss = 1.25f * (Fss * (1 / (ndotl + ndotv) - 0.5f) + 0.5f);

                float3 diffuse = lerp(Fd, ss, _Subsurface) * albedo;

                // Specular
                float alpha = _Roughness * _Roughness;
                float alphaSquared = alpha * alpha;

                // Anisotropic Microfacet Normal Distribution (Normalized Anisotropic GTR gamma == 2)
                float aspectRatio = sqrt(1.0f - _Anisotropic * 0.9f);
                float alphaX = max(0.001f, alphaSquared / aspectRatio);
                float alphaY = max(0.001f, alphaSquared * aspectRatio);
                float Ds = AnisotropicGTR2(ndoth, dot(H, X), dot(H, Y), alphaX, alphaY);

                float ndf = GGX(alphaSquared, ndoth);
                ndf = Ds;

                float G = SmithGGX(alphaSquared, ndotl, ndotv); // specular brdf denominator (4 * ndotl * ndotv) is baked into output here  

                float F0 = _Specular;
                float F = lerp(F0, 1.0f, SchlickFresnel(ldoth));


                float3 output = diffuse * (1 - F) + (ndf * F * G);
                output *= ndotl;

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