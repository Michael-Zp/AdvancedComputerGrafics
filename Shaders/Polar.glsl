#version 330

#include "libs/Noise.glsl"

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

#define PI 3.14159

float min3(vec3 vec)
{
	return min(min(vec.x, vec.y), vec.z);
}

float minMat3(mat3 matrix)
{
	return min3(vec3(min3(matrix[0]), min3(matrix[1]), min3(matrix[2])));
}


vec3 circleWithPolar(float radius, float thickness, vec2 polarPosition)
{
	return vec3(smoothstep(0, thickness, abs(radius - polarPosition.x)));
}

vec3 sinusWithPolar(float radius, float thickness, vec2 polarPosition) 
{
	return vec3(smoothstep(0, thickness, abs(radius + .05 * sin(16 * polarPosition.y) - polarPosition.x)));
}

vec3 everythingSmallerThanSinusWithPolar(float radius, vec2 polarPosition)
{
	return vec3(step(polarPosition.x, abs(radius + .2 * sin(8 * polarPosition.y))));
}

void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);

	uv -= .5;
	uv *= 2;

	//color.rgb = vec3(atan(uv.y, uv.x), abs(atan(uv.y, uv.x)), 1);

	vec2 polar = vec2(length(uv), atan(uv.y, uv.x));

	color = vec4( sin( polar. y - 3.141459 * 0.5 ) * 0.5 + 0.5 );

	//color.rgb = vec3( polar.y / (3.1415 * 2) / 2 + .5 ); 

	//color.rgb = circleWithPolar(.25, .05, polar);

	//color.rgb = sinusWithPolar(.5, .05, polar);

	color.rgb = everythingSmallerThanSinusWithPolar(.5, polar);
	color.rgb *= vec3(1 - step(.54, polar.x));
	color.rgb += vec3(1 - step(.45, polar.x));


	gl_FragColor = color;
}