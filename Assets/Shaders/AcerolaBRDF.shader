Shader "Acerola/AcerolaBRDF" {

    Properties {
        _AlbedoTex ("Albedo", 2D) = "" {}
        _NormalTex ("Normal", 2D) = "" {}
        _TangentTex ("Tangent", 2D) = "" {}
        _NormalStrength ("Normal Strength", Range(0.0, 3.0)) = 1.0
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0
        _Subsurface ("Subsurface", Range(0.0, 1.0)) = 0
        _Specular ("Specular", Range(0.0, 2.0)) = 0.5
        _RoughnessTex ("Roughness Map", 2D) = "" {}
        _RoughnessMapMod ("Roughness Map Mod", Range(0.0, 1.0)) = 0.5
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.5
        _SpecularTint ("Specular Tint", Range(0.0, 1.0)) = 0.0
        _Anisotropic ("Anisotropic", Range(0.0, 1.0)) = 0.0
        _Sheen ("Sheen", Range(0.0, 1.0)) = 0.0
        _SheenTint ("Sheen Tint", Range(0.0, 1.0)) = 0.5
        _ClearCoat ("Clear Coat", Range(0.0, 1.0)) = 0.0
        _ClearCoatGloss ("Clear Coat Gloss", Range(0.0, 1.0)) = 1.0
        _SkyboxCube ("Skybox", Cube) = "" {}
        _IndirectF0 ("Indirect Min Reflectance", Range(0.0, 1.0)) = 0.0
        _IndirectF90 ("Indirect Max Reflectance", Range(0.0, 1.0)) = 0.0
        [HideInInspector]_TextureSetIndex1 ("Texture Set Index", Range(1, 1)) = 1
        [HideInInspector]_BlendFactor ("_", Range(1, 1)) = 0
    }

    SubShader {

        CGINCLUDE
        
        #include "UnityPBSLighting.cginc"
        #include "AutoLight.cginc"

        #define PI 3.14159265f

        samplerCUBE _SkyboxCube;
        sampler2D _AlbedoTex, _NormalTex, _TangentTex, _RoughnessTex;
        sampler2D _AlbedoTex2, _NormalTex2, _TangentTex2, _RoughnessTex2;
        float3 _BaseColor;
        float _NormalStrength, _Roughness, _Metallic, _Subsurface, _Specular, _SpecularTint, _Anisotropic, _Sheen, _SheenTint, _ClearCoat, _ClearCoatGloss;
        float _RoughnessMapMod, _IndirectF0, _IndirectF90;
        int _TextureSetIndex1, _TextureSetIndex2;
        float _BlendFactor;

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

        // Isotropic Generalized Trowbridge Reitz with gamma == 1
        float GTR1(float ndoth, float a) {
            float a2 = a * a;
            float t = 1.0f + (a2 - 1.0f) * ndoth * ndoth;
            return (a2 - 1.0f) / (PI * log(a2) * t);
        }

        // Anisotropic Generalized Trowbridge Reitz with gamma == 2. This is equal to the popular GGX distribution.
        float AnisotropicGTR2(float ndoth, float hdotx, float hdoty, float ax, float ay) {
            return rcp(PI * ax * ay * sqr(sqr(hdotx / ax) + sqr(hdoty / ay) + sqr(ndoth)));
        }

        // Isotropic Geometric Attenuation Function for GGX. This is technically different from what Disney uses, but it's basically the same.
        float SmithGGX(float alphaSquared, float ndotl, float ndotv) {
            float a = ndotv * sqrt(alphaSquared + ndotl * (ndotl - alphaSquared * ndotl));
            float b = ndotl * sqrt(alphaSquared + ndotv * (ndotv - alphaSquared * ndotv));

            return 0.5f / (a + b);
        }

        // Anisotropic Geometric Attenuation Function for GGX.
        float AnisotropicSmithGGX(float ndots, float sdotx, float sdoty, float ax, float ay) {
            return rcp(ndots + sqrt(sqr(sdotx * ax) + sqr(sdoty * ay) + sqr(ndots)));
        }

        struct BRDFInput {
            float3 L; // Direction to light source
            float3 V; // Direction to camera/viewer
            float3 N; // World space normal (unpacked from normal map)
            float3 X; // World space tangent (unpacked from tangent map)
            float3 Y; // World space bitangent
            float roughness; // From uniform or texture map
            float3 baseColor;
        };

        struct BRDFResults {
            float3 diffuse;
            float3 specular;
            float3 clearcoat;
        };

        BRDFResults DisneyBRDF(BRDFInput i) {
            BRDFResults output;
            output.diffuse = 0.0f;
            output.specular = 0.0f;
            output.clearcoat = 0.0f;

            float3 H = normalize(i.L + i.V); // Microfacet normal of perfect reflection

            float ndotl = DotClamped(i.N, i.L);
            float ndotv = DotClamped(i.N, i.V);
            float ndoth = DotClamped(i.N, H);
            float ldoth = DotClamped(i.L, H);

            float Cdlum = luminance(i.baseColor);

            float3 Ctint = Cdlum > 0.0f ? i.baseColor / Cdlum : 1.0f;
            float3 Cspec0 = lerp(_Specular * 0.08f * lerp(1.0f, Ctint, _SpecularTint), i.baseColor * (1.0f + _Specular), _Metallic);
            float3 Csheen = lerp(1.0f, Ctint, _SheenTint);


            // Disney Diffuse
            float FL = SchlickFresnel(ndotl);
            float FV = SchlickFresnel(ndotv);

            float Fss90 = ldoth * ldoth * i.roughness;
            float Fd90 = 0.5f + 2.0f * Fss90;

            float Fd = lerp(1.0f, Fd90, FL) * lerp(1.0f, Fd90, FV);

            // Subsurface Diffuse (Hanrahan-Krueger brdf approximation)

            float Fss = lerp(1.0f, Fss90, FL) * lerp(1.0f, Fss90, FV);
            float ss = 1.25f * (Fss * (rcp(ndotl + ndotv) - 0.5f) + 0.5f);

            // Specular
            float alpha = i.roughness;
            float alphaSquared = alpha * alpha;

            // Anisotropic Microfacet Normal Distribution (Normalized Anisotropic GTR gamma == 2)
            float aspectRatio = sqrt(1.0f - _Anisotropic * 0.9f);
            float alphaX = max(0.001f, alphaSquared / aspectRatio);
            float alphaY = max(0.001f, alphaSquared * aspectRatio);
            float Ds = AnisotropicGTR2(ndoth, dot(H, i.X), dot(H, i.Y), alphaX, alphaY);

            // Geometric Attenuation
            float GalphaSquared = sqr(0.5f + i.roughness * 0.5f);
            float GalphaX = max(0.001f, GalphaSquared / aspectRatio);
            float GalphaY = max(0.001f, GalphaSquared * aspectRatio);
            float G = AnisotropicSmithGGX(ndotl, dot(i.L, i.X), dot(i.L, i.Y), GalphaX, GalphaY);
            G *= AnisotropicSmithGGX(ndotv, dot(i.V, i.X), dot (i.V, i.Y), GalphaX, GalphaY); // specular brdf denominator (4 * ndotl * ndotv) is baked into output here (I assume at least)  

            // Fresnel Reflectance
            float FH = SchlickFresnel(ldoth);
            float3 F = lerp(Cspec0, 1.0f, FH);

            // Sheen
            float3 Fsheen = FH * _Sheen * Csheen;

            // Clearcoat (Hard Coded Index Of Refraction -> 1.5f -> F0 -> 0.04)
            float Dr = GTR1(ndoth, lerp(0.1f, 0.001f, _ClearCoatGloss)); // Normalized Isotropic GTR Gamma == 1
            float Fr = lerp(0.04, 1.0f, FH);
            float Gr = SmithGGX(ndotl, ndotv, 0.25f);

            
            output.diffuse = (1.0f / PI) * (lerp(Fd, ss, _Subsurface) * i.baseColor + Fsheen) * (1 - _Metallic) * (1 - F);
            output.specular = saturate(Ds * F * G);
            // output.specular = F;
            output.clearcoat = saturate(0.25f * _ClearCoat * Gr * Fr * Dr);

            return output;
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
                
                float3 unnormalizedNormalWS = i.normal;
                float renormFactor = 1.0f / length(unnormalizedNormalWS);

                float3x3 worldToTangent;
                float3 bitangent = cross(unnormalizedNormalWS, i.tangent.xyz) * i.tangent.w;
                worldToTangent[0] = i.tangent.xyz * renormFactor;
                worldToTangent[1] = bitangent * renormFactor;
                worldToTangent[2] = unnormalizedNormalWS * renormFactor;

                // Unpack DXT5nm tangent space normal
                float4 packedNormal = tex2D(_NormalTex, uv);
                packedNormal.w *= packedNormal.x;

                float3 N;
                N.xy = packedNormal.wy * 2.0f - 1.0f;
                N.xy *= _NormalStrength;
                N.z = sqrt(1.0f - saturate(dot(N.xy, N.xy)));
                N = mul(N, worldToTangent);
                if (_TextureSetIndex1 == 0) N = i.normal;

                // Unpack DXT5nm tangent space tangent
                float3 T;
                T.xy = tex2D(_TangentTex, uv).wy * 2 - 1;
                T.z = sqrt(1 - saturate(dot(T.xy, T.xy)));
                
                T = mul(lerp(float3(1.0f, 0.0f, 0.0f), T, saturate(_NormalStrength)), worldToTangent);
                if (_TextureSetIndex1 == 0) T = i.tangent.xyz;
                
                float3 albedo = tex2D(_AlbedoTex, uv).rgb;
                if (_TextureSetIndex1 == 0) albedo = 1.0f;
                albedo *= _BaseColor;

                float roughnessMap = tex2D(_RoughnessTex, uv).r;
                if (_TextureSetIndex1 == 0) roughnessMap = 0.0f;

                // Unpack DXT5nm tangent space normal
                float4 packedNormal2 = tex2D(_NormalTex2, uv);
                packedNormal2.w *= packedNormal2.x;

                float3 N2;
                N2.xy = packedNormal2.wy * 2.0f - 1.0f;
                N2.xy *= _NormalStrength;
                N2.z = sqrt(1.0f - saturate(dot(N2.xy, N2.xy)));
                N2 = mul(N2, worldToTangent);
                if (_TextureSetIndex2 == 0) N2 = i.normal;

                // Unpack DXT5nm tangent space tangent
                float3 T2;
                T2.xy = tex2D(_TangentTex2, uv).wy * 2 - 1;
                T2.z = sqrt(1 - saturate(dot(T2.xy, T2.xy)));
                
                T2 = mul(lerp(float3(1.0f, 0.0f, 0.0f), T2, saturate(_NormalStrength)), worldToTangent);
                if (_TextureSetIndex2 == 0) T2 = i.tangent.xyz;
                
                float3 albedo2 = tex2D(_AlbedoTex2, uv).rgb;
                if (_TextureSetIndex2 == 0) albedo2 = 1.0f;
                albedo2 *= _BaseColor;

                float roughnessMap2 = tex2D(_RoughnessTex2, uv).r;
                if (_TextureSetIndex2 == 0) roughnessMap2 = 0.0f;

                BRDFInput input;

                float3 finalNormal = normalize(lerp(N, N2, _BlendFactor));
                float3 finalTangent = normalize(lerp(T, T2, _BlendFactor));

                input.N = finalNormal;
                input.L = normalize(_WorldSpaceLightPos0.xyz); // Direction *towards* light source
                input.V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz); // Direction *towards* camera
                input.X = finalTangent;
                input.Y = (cross(finalNormal, finalTangent) * i.tangent.w); // Bitangent
                input.roughness = max(_Roughness, lerp(roughnessMap, roughnessMap2, _BlendFactor));
                input.baseColor = lerp(albedo, albedo2, _BlendFactor);

                // return input.roughness;

                BRDFResults reflection = DisneyBRDF(input);

                float3 output = _LightColor0 * (reflection.diffuse + reflection.specular + reflection.clearcoat);
                output *= DotClamped(input.N, input.L);
                output *= SHADOW_ATTENUATION(i);
                output = max(0.0f, output);

                float indirectRoughness = max(_Roughness, roughnessMap);

                float skyboxMip = lerp(0.0f, 10.0f, pow(indirectRoughness, rcp(2.0f)));
                float mip1 = floor(skyboxMip);
                float mip2 = ceil(skyboxMip);
                float t = frac(skyboxMip);

                input.L = finalNormal;

                BRDFResults indirectReflection = DisneyBRDF(input);

                float3 indirectReflection1 = texCUBElod(_SkyboxCube, float4(finalNormal, mip1)).rgb;
                float3 indirectReflection2 = texCUBElod(_SkyboxCube, float4(finalNormal, mip2)).rgb;
                float3 indirectReflectionColor = lerp(indirectReflection1, indirectReflection2, t) * lerp(1.0f, input.baseColor, _Metallic);
                
                output += indirectReflectionColor * max(_IndirectF0, (indirectReflection.diffuse + indirectReflection.specular + indirectReflection.clearcoat) * _IndirectF90);

                return float4(output, 1.0f);
            }

            ENDCG
        }

        Pass {
            Tags {
                "LightMode" = "ForwardAdd"
            }

            Blend One One
            Zwrite Off

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
                
                float3 unnormalizedNormalWS = i.normal;
                float renormFactor = 1.0f / length(unnormalizedNormalWS);

                float3x3 worldToTangent;
                float3 bitangent = cross(unnormalizedNormalWS, i.tangent.xyz) * i.tangent.w;
                worldToTangent[0] = i.tangent.xyz * renormFactor;
                worldToTangent[1] = bitangent * renormFactor;
                worldToTangent[2] = unnormalizedNormalWS * renormFactor;

                // Unpack DXT5nm tangent space normal
                float4 packedNormal = tex2D(_NormalTex, uv);
                packedNormal.w *= packedNormal.x;

                float3 N;
                N.xy = packedNormal.wy * 2.0f - 1.0f;
                N.xy *= _NormalStrength;
                N.z = sqrt(1.0f - saturate(dot(N.xy, N.xy)));
                N = mul(N, worldToTangent);

                // Unpack DXT5nm tangent space tangent
                float3 T;
                T.xy = tex2D(_TangentTex, uv).wy * 2 - 1;
                T.z = sqrt(1 - saturate(dot(T.xy, T.xy)));

                T = mul(lerp(float3(1.0f, 0.0f, 0.0f), T, saturate(_NormalStrength)), worldToTangent);
                
                float3 albedo = tex2D(_AlbedoTex, uv).rgb;
                albedo *= _BaseColor;

                BRDFInput input;

                input.N = N;
                input.L = normalize(_WorldSpaceLightPos0.xyz); // Direction *towards* light source
                input.V = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz); // Direction *towards* camera
                input.X = normalize(T);
                input.Y = normalize(cross(N, T) * i.tangent.w);
                input.roughness = max(_Roughness, tex2D(_RoughnessTex, uv).r);
                input.baseColor = albedo;

                BRDFResults reflection = DisneyBRDF(input);

                float3 output = _LightColor0 * (reflection.diffuse * albedo + reflection.specular + reflection.clearcoat);
                output *= DotClamped(input.N, input.L);

                return float4(max(0.0f, output), 1.0f);
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