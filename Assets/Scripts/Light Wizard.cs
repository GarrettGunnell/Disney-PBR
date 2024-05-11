using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class LightWizard : MonoBehaviour {
    
    public Slider redSlider, blueSlider, greenSlider, intensitySlider, verticalSlider, horizontalSlider;

    private Light lightComponent;
    void OnEnable() {
        lightComponent = GetComponent<Light>();
    }

    void Update() {
        lightComponent.color = new Color(redSlider.value, greenSlider.value, blueSlider.value);
        lightComponent.intensity = intensitySlider.value;

        Vector3 newRotation = new Vector3(verticalSlider.value, horizontalSlider.value, 0.0f);
        this.transform.rotation = Quaternion.Euler(newRotation);
    }
}
