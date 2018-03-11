#version 330

#include "../libs/rayIntersections.glsl"
#include "../libs/camera.glsl"


uniform float iGlobalTime;
uniform vec2 iResolution;

uniform sampler2D tex0;

in vec2 uv;

const float PI = 3.1415;
const float TAU = PI * 2.0;

vec2 calcUvOnSphere(vec3 hitPoint, vec3 sphereCenter)
{
    vec3 centerToHitPoint = normalize(hitPoint - sphereCenter);

    return vec2(centerToHitPoint.x, centerToHitPoint.y) / 2.0 + vec2(0.5);
}

void main()
{
    vec4 color = vec4(0, 0, 0, 1);

	vec3 camP = calcCameraPos();
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);

    vec3 sphereCenter = vec3(0, 0, 2);

    float t = sphere(sphereCenter, 1.0, Ray(camP, camDir), 1e-5);

    vec3 hitPoint = camP + camDir * t;

    vec2 sphereUv = calcUvOnSphere(hitPoint, sphereCenter);

    t = step(0.0, t);

    color.rgb = vec3(sphereUv.x * t, sphereUv.y * t, 0);


    gl_FragColor = color;
}