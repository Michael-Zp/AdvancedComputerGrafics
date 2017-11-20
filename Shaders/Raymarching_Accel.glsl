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
	
	vec2 txtSize = textureSize(tex0, 2);
	float xSize = 1 / txtSize.x;
	float ySize = 1 / txtSize.y;

	
	float heightAtThisPoint = texture(tex0, uv).x;

	float maxAngle = 0;

	for(int radius = 1; radius < 2; radius++) 
	{
		for(int x = -radius; x <= radius; x++) 
		{
			for(int y = -radius; y <= radius; y++) 
			{
				if(x == 0 && y == 0)
					continue;

				vec2 offset = vec2(xSize * x, ySize * y);
				vec2 nextCoord = uv + offset;

				if (nextCoord.x < 0 || nextCoord.x > 1)
					continue;

				if (nextCoord.y < 0 || nextCoord.y > 1)
					continue;
			
				float heightNextStep = texture(tex0, nextCoord, 0).x;
			
				float angle = atan((heightNextStep - heightAtThisPoint) / length(offset));

				maxAngle = max(angle, maxAngle);
			}
		}
	}

	float coneAngle = 2 * PI - 2 * maxAngle;
	
	
	color.rgb = vec3(coneAngle);

	gl_FragColor = color;

}