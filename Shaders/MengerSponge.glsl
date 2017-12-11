#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]
	
#include "libs/camera.glsl"

#define PI 3.1415
#define EPSILON 1e-5
#define STEPS 500

const float BIG_FLT = 1e20;

struct Ray 
{
	vec3 origin;
	vec3 direction;
};

float sdBox( vec3 p, vec3 b )
{
  vec3 d = abs(p) - b;
  return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

float sdBox2D( vec2 p, vec2 b )
{
  vec2 d = abs(p) - b;
  return min(d.x,0.0) + length(max(d,0.0));
}

float distanceCross(in vec3 position)
{
	float xDirBox = sdBox(position, vec3(BIG_FLT, 1.0, 1.0));
	float yDirBox = sdBox(position, vec3(1.0, BIG_FLT, 1.0));
	float zDirBox = sdBox(position, vec3(1.0, 1.0, BIG_FLT));

	return min(xDirBox, min(yDirBox, zDirBox));
}

float sdCross( in vec3 p )
{
  float da = sdBox2D(p.xy,vec2(1.0));
  float db = sdBox2D(p.yz,vec2(1.0));
  float dc = sdBox2D(p.zx,vec2(1.0));
  return min(da,min(db,dc));
}

float map(in vec3 position) 
{
	float d = sdBox(position, vec3(1.0));

	float s = 1.0;
	for( int m=0; m<3; m++ )
	{
		vec3 a = mod( position*s, 2.0 )-1.0;
		s *= 3.0;
		vec3 r = 1.0 - 3.0*abs(a);

		float c = distanceCross(r)/s;
		d = max(d,c);
	}

	return d;
}



void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);

	
	vec3 camP = calcCameraPos();
	camP.z -= 3;
	vec3 camDir = calcCameraRayDir(80.0, gl_FragCoord.xy, iResolution);

	
	struct Ray ray;
	ray.origin = camP;
	ray.direction = camDir;

	const float delta = 0.008f;

	vec3 currPos = ray.origin;

	for(int i = 0; i < STEPS; i++)
	{
		float dist = map(currPos);

		if(dist < EPSILON) 
		{
			color.rgb = 1 - (vec3(1) * i) / STEPS;
			break;
		}

		currPos = currPos + ray.direction * delta;
	}

	gl_FragColor = color;

}