#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

uniform sampler2D tex0; //Texture



#define PI 3.1415


void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(texture(tex0, uv).rgb, 1);
	
	//vec2 txtSize = textureSize(tex0, 0);
	const vec2 txtSize = vec2(256, 256);
	const float maxHeight = 1;
	const float xSize = 1 / txtSize.x;
	const float ySize = 1 / txtSize.y;

	
	float heightAtThisPoint = texture(tex0, uv).z;
	
	vec3 thisPoint = vec3(uv, heightAtThisPoint);

	float minAngle = .5 * PI;
	
	if(heightAtThisPoint != maxHeight) 
	{
		for(int radius = 1; radius < txtSize.x; radius++) 
		{
			vec2 maxHeightCoord = vec2(uv.x + radius * xSize, uv.y);
			vec3 maxHeightPoint = vec3(maxHeightCoord, maxHeight);
			float minPossibleAngle = acos(dot(normalize(maxHeightPoint - thisPoint), vec3(0, 0, 1)));

			if(minAngle < minPossibleAngle)
			{
				break;
			}

			for(int x = -radius; x <= radius; x += radius * 2) 
			{
				for(int y = -radius; y <= radius; y++) 
				{
					vec2 offset = vec2(xSize * x, ySize * y);
					vec2 nextCoord = uv + offset;
				
					nextCoord.x = clamp(nextCoord.x, xSize, 1 - xSize);
					nextCoord.y = clamp(nextCoord.y, ySize, 1 - ySize);
				
					float heightNextPoint = texture(tex0, nextCoord).z;

					vec3 nextPoint = vec3(nextCoord, heightNextPoint);

					float nextAngle = acos(dot(normalize(nextPoint - thisPoint), vec3(0, 0, 1)));
					minAngle = min(minAngle, nextAngle);
				}
			}

			for(int y = -radius; y <= radius; y += radius * 2) 
			{
				for(int x = -radius; x <= radius; x++) 
				{
					vec2 offset = vec2(xSize * x, ySize * y);
					vec2 nextCoord = uv + offset;
				
					nextCoord.x = clamp(nextCoord.x, xSize, 1 - xSize);
					nextCoord.y = clamp(nextCoord.y, ySize, 1 - ySize);
				
					float heightNextPoint = texture(tex0, nextCoord).z;

					vec3 nextPoint = vec3(nextCoord, heightNextPoint);

					float nextAngle = acos(dot(normalize(nextPoint - thisPoint), vec3(0, 0, 1)));
					minAngle = min(minAngle, nextAngle);
				}
			}
		}
	}

		
	color.rgb = vec3(minAngle);


	gl_FragColor = color;

}
