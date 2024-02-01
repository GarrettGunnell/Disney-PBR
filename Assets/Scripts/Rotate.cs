using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Rotate : MonoBehaviour {

    [Range(0.0f, 360.0f)]
    public float speed = 1.0f;
    // Update is called once per frame
    void Update() {
        this.transform.Rotate(0.0f, speed * Time.deltaTime, 0.0f, Space.World);
    }
}
