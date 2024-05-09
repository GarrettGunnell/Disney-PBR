using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class MaterialWizard : MonoBehaviour {
    public Shader shader;

    public TMP_Dropdown materialDropdown;
    // Great code
    public Slider redSlider, greenSlider, blueSlider, normalScaleSlider, metallicSlider, subsurfaceSlider, specularSlider,
    specularTintSlider, roughnessSlider, anisotropicSlider, sheenSlider, sheenTintSlider, clearCoatSlider, clearCoatGlossSlider;

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

    void FillMaterialInfo() {
        MaterialInfo activeMaterialInfo = materialDropdown.value == 0 ? materialInfo1 : materialInfo2;

        activeMaterialInfo.textureSet = 0;
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

    void SetUniforms() {
        MaterialInfo activeMaterialInfo = materialDropdown.value == 0 ? materialInfo1 : materialInfo2;

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
