using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using TMPro;

public class SliderValue : MonoBehaviour {
    private Slider parentSlider;
    private TextMeshProUGUI textMesh;

    void OnEnable() {
        parentSlider = GetComponentInParent<Slider>();
        textMesh = GetComponent<TextMeshProUGUI>();
    }

    void Update() {
        textMesh.text = parentSlider.value.ToString("0.00");
    }
}
