#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

uniform sampler2D tex0; //Texture



#define PI 3.1415

struct Ray 
{
	vec3 origin;
	vec3 direction;
};


struct Ray GetCameraRay(vec3 origin, float fov, vec2 pos, vec2 resolution) 
{
	//Camera Ray
	struct Ray ray;
	float fx = tan(fov / 2) / resolution.x;
	vec2 d = (2 * pos - resolution) * fx;
	ray.direction = normalize(vec3(d, 1));
	ray.origin = origin;
	return ray;
}



void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(texture(tex0, uv).rgb, 1);
	
	struct Ray ray = GetCameraRay(vec3(0, 1, 0), .5 * PI, gl_FragCoord.xy, iResolution);



	gl_FragColor = color;

}