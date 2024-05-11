using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class MaterialWizard : MonoBehaviour {
    public Shader shader;
    public Toggle hdrToggle;

    public TMP_Dropdown materialDropdown, textureSetDropdown, skyboxDropdown;
    // Great code
    public Slider redSlider, greenSlider, blueSlider, normalScaleSlider, metallicSlider, subsurfaceSlider, specularSlider,
    specularTintSlider, roughnessSlider, anisotropicSlider, sheenSlider, sheenTintSlider, clearCoatSlider, clearCoatGlossSlider,
    indirectMinStrengthSlider, indirectMaxStrengthSlider, blendSlider, skyboxIntensitySlider;

    public Texture skybox1, skybox2, skybox3;
    public Material skyboxMaterial1, skyboxMaterial2, skyboxMaterial3, skyboxMaterial4;
    public Texture albedo1, normals1, tangents1, roughness1;
    public Texture albedo2, normals2, tangents2, roughness2;
    public Texture albedo3, normals3, tangents3, roughness3;
    public Texture albedo4, normals4, tangents4, roughness4;
    public Texture albedo5, normals5, tangents5, roughness5;

    private class MaterialInfo {
        public int textureSet;
        public Vector3 baseColor;
        public float normalScale;
        public float metallic;
        public float subsurface;
        public float specular;
        public float specularTint;
        public float minimumRoughness;
        public float anisotropic;
        public float sheen;
        public float sheenTint;
        public float clearCoat;
        public float clearCoatGloss;

        public MaterialInfo() {
            textureSet = 0;
            baseColor = new Vector3(1, 1, 1);
            normalScale = 1.0f;
            metallic = 0.0f;
            subsurface = 0.0f;
            specular = 0.0f;
            specularTint = 0.0f;
            minimumRoughness = 0.4f;
            anisotropic = 0.0f;
            sheen = 0.0f;
            sheenTint = 0.0f;
            clearCoat = 0.0f;
            clearCoatGloss = 0.0f;
        }
    }

    private MaterialInfo materialInfo1, materialInfo2;
    private int cachedMaterialIndex;
    private Material material;
    private Renderer meshRenderer;

    private Vector3 GetColorFromUI() {
        return new Vector3(redSlider.value, greenSlider.value, blueSlider.value);
    }

    private Texture GetSkyboxTex(int i) {
        if (i == 0) return skybox1;
        if (i == 1) return skybox2;
        if (i == 2) return skybox3;

        return skybox1;
    }

    private Material GetSkyboxMaterial(int i) {
        if (i == 0) return skyboxMaterial1;
        if (i == 1) return skyboxMaterial2;
        if (i == 2) return skyboxMaterial3;
        if (i == 3) return skyboxMaterial4;

        return skyboxMaterial1;
    }

    private Texture GetAlbedoTex(int i) {
        if (i == 1) return albedo1;
        if (i == 2) return albedo2;
        if (i == 3) return albedo3;
        if (i == 4) return albedo4;
        if (i == 5) return albedo5;

        return albedo1;
    }

    private Texture GetNormalsTex(int i) {
        if (i == 1) return normals1;
        if (i == 2) return normals2;
        if (i == 3) return normals3;
        if (i == 4) return normals4;
        if (i == 5) return normals5;

        return normals1;
    }

    private Texture GetTangentsTex(int i) {
        if (i == 1) return tangents1;
        if (i == 2) return tangents2;
        if (i == 3) return tangents3;
        if (i == 4) return tangents4;
        if (i == 5) return tangents5;

        return tangents1;
    }

    private Texture GetRoughnessTex(int i) {
        if (i == 1) return roughness1;
        if (i == 2) return roughness2;
        if (i == 3) return roughness3;
        if (i == 4) return roughness4;
        if (i == 5) return roughness5;

        return roughness1;
    }

    void FillMaterialInfo() {
        MaterialInfo activeMaterialInfo = materialDropdown.value == 0 ? materialInfo1 : materialInfo2;

        activeMaterialInfo.textureSet = textureSetDropdown.value;
        activeMaterialInfo.baseColor = GetColorFromUI();
        activeMaterialInfo.normalScale = normalScaleSlider.value;
        activeMaterialInfo.metallic = metallicSlider.value;
        activeMaterialInfo.subsurface = subsurfaceSlider.value;
        activeMaterialInfo.specular = specularSlider.value;
        activeMaterialInfo.specularTint = specularTintSlider.value;
        activeMaterialInfo.minimumRoughness = roughnessSlider.value;
        activeMaterialInfo.anisotropic = anisotropicSlider.value;
        activeMaterialInfo.sheen = sheenSlider.value;
        activeMaterialInfo.sheenTint = sheenTintSlider.value;
        activeMaterialInfo.clearCoat = clearCoatSlider.value;
        activeMaterialInfo.clearCoatGloss = clearCoatGlossSlider.value;
    }

    void SwapMaterials() {
        MaterialInfo activeMaterialInfo = materialDropdown.value == 0 ? materialInfo1 : materialInfo2;
        blendSlider.value = materialDropdown.value;

        textureSetDropdown.value = activeMaterialInfo.textureSet;
        redSlider.value = activeMaterialInfo.baseColor.x;
        greenSlider.value = activeMaterialInfo.baseColor.y;
        blueSlider.value = activeMaterialInfo.baseColor.z;
        normalScaleSlider.value = activeMaterialInfo.normalScale;
        metallicSlider.value = activeMaterialInfo.metallic;
        subsurfaceSlider.value = activeMaterialInfo.subsurface;
        specularSlider.value = activeMaterialInfo.specular;
        specularTintSlider.value = activeMaterialInfo.specularTint;
        roughnessSlider.value = activeMaterialInfo.minimumRoughness;
        anisotropicSlider.value = activeMaterialInfo.anisotropic;
        sheenSlider.value = activeMaterialInfo.sheen;
        sheenTintSlider.value = activeMaterialInfo.sheenTint;
        clearCoatSlider.value = activeMaterialInfo.clearCoat;
        clearCoatGlossSlider.value = activeMaterialInfo.clearCoatGloss;

        cachedMaterialIndex = materialDropdown.value;
    }

    MaterialInfo BlendMaterials() {
        MaterialInfo i = new MaterialInfo();

        i.baseColor = Vector3.Lerp(materialInfo1.baseColor, materialInfo2.baseColor, blendSlider.value);
        i.normalScale = Mathf.Lerp(materialInfo1.normalScale, materialInfo2.normalScale, blendSlider.value);
        i.metallic = Mathf.Lerp(materialInfo1.metallic, materialInfo2.metallic, blendSlider.value);
        i.subsurface = Mathf.Lerp(materialInfo1.subsurface, materialInfo2.subsurface, blendSlider.value);
        i.specular = Mathf.Lerp(materialInfo1.specular, materialInfo2.specular, blendSlider.value);
        i.specularTint = Mathf.Lerp(materialInfo1.specularTint, materialInfo2.specularTint, blendSlider.value);
        i.minimumRoughness = Mathf.Lerp(materialInfo1.minimumRoughness, materialInfo2.minimumRoughness, blendSlider.value);
        i.anisotropic = Mathf.Lerp(materialInfo1.anisotropic, materialInfo2.anisotropic, blendSlider.value);
        i.sheen = Mathf.Lerp(materialInfo1.sheen, materialInfo2.sheen, blendSlider.value);
        i.sheenTint = Mathf.Lerp(materialInfo1.sheenTint, materialInfo2.sheenTint, blendSlider.value);
        i.clearCoat = Mathf.Lerp(materialInfo1.clearCoat, materialInfo2.clearCoat, blendSlider.value);
        i.clearCoatGloss = Mathf.Lerp(materialInfo1.clearCoatGloss, materialInfo2.clearCoatGloss, blendSlider.value);

        return i;
    }

    void SetUniforms() {
        MaterialInfo activeMaterialInfo = BlendMaterials();

        material.SetVector("_BaseColor", activeMaterialInfo.baseColor);
        material.SetFloat("_NormalStrength", activeMaterialInfo.normalScale);
        material.SetFloat("_Metallic", activeMaterialInfo.metallic);
        material.SetFloat("_Subsurface", activeMaterialInfo.subsurface);
        material.SetFloat("_Specular", activeMaterialInfo.specular);
        material.SetFloat("_SpecularTint", activeMaterialInfo.specularTint);
        material.SetFloat("_Roughness", activeMaterialInfo.minimumRoughness);
        material.SetFloat("_Anisotropic", activeMaterialInfo.anisotropic);
        material.SetFloat("_Sheen", activeMaterialInfo.sheen);
        material.SetFloat("_SheenTint", activeMaterialInfo.sheenTint);
        material.SetFloat("_ClearCoat", activeMaterialInfo.clearCoat);
        material.SetFloat("_ClearCoatGloss", activeMaterialInfo.clearCoatGloss);
        material.SetFloat("_IndirectF0", indirectMinStrengthSlider.value);
        material.SetFloat("_IndirectF90", indirectMaxStrengthSlider.value);

        material.SetInt("_TextureSetIndex1", materialInfo1.textureSet);
        material.SetInt("_TextureSetIndex2", materialInfo2.textureSet);
        material.SetFloat("_BlendFactor", blendSlider.value);
        material.SetTexture("_AlbedoTex", GetAlbedoTex(materialInfo1.textureSet));
        material.SetTexture("_NormalTex", GetNormalsTex(materialInfo1.textureSet));
        material.SetTexture("_TangentTex", GetTangentsTex(materialInfo1.textureSet));
        material.SetTexture("_RoughnessTex", GetRoughnessTex(materialInfo1.textureSet));
        material.SetTexture("_AlbedoTex2", GetAlbedoTex(materialInfo2.textureSet));
        material.SetTexture("_NormalTex2", GetNormalsTex(materialInfo2.textureSet));
        material.SetTexture("_TangentTex2", GetTangentsTex(materialInfo2.textureSet));
        material.SetTexture("_RoughnessTex2", GetRoughnessTex(materialInfo2.textureSet));

        Material skyboxMaterial = GetSkyboxMaterial(skyboxDropdown.value);
        skyboxMaterial.SetFloat("_Exposure", hdrToggle.isOn ? 1.4f : 1.0f);
        RenderSettings.skybox = skyboxMaterial;
        material.SetTexture("_SkyboxCube", GetSkyboxTex(skyboxDropdown.value));
        material.SetFloat("_SkyboxIntensity", skyboxIntensitySlider.value);
    }

    void OnEnable() {
        cachedMaterialIndex = 0;
        materialInfo1 = new MaterialInfo();
        materialInfo2 = new MaterialInfo();

        material = new Material(shader);
        FillMaterialInfo();
        SetUniforms();

        meshRenderer = this.GetComponent<Renderer>();

        meshRenderer.material = material;
    }

    void Update() {
        if (materialDropdown.value != cachedMaterialIndex) SwapMaterials();

        FillMaterialInfo();
        SetUniforms();
    }
}
