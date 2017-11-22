#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

uniform sampler2D tex0; //Texture

#include "libs/camera.glsl"

#define PI 3.1415


struct Ray 
{
	vec3 origin;
	vec3 direction;
};



void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(vec3(0), 1);
	//color = vec4(uv, 0, 1);
	
	vec3 camP = calcCameraPos();
	camP.y += 2;
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);

	
	struct Ray ray;
	ray.origin = camP;
	ray.direction = camDir;


	const float delta = 0.005f;
	bool hitSomething = false;

	vec3 currPos = ray.origin;

	float maxSteps = abs(ray.origin.z / delta) * 3;

	for(int i = 0; i < maxSteps && !hitSomething; i++)
	{
		vec2 coordInTex = vec2(currPos.x, currPos.y);

		float height = texture(tex0, coordInTex).r;

		if(currPos.z > -height) 
		{
			color.r = height;
			color.g = 1 - height;
			color.b = 0;
			hitSomething = true;
		}

		currPos = currPos + ray.direction * delta;
	}




	gl_FragColor = color;

}