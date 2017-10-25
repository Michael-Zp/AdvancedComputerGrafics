#version 330

#include "libs/Noise.glsl"

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

vec2 randomPositionFromGridPosition(vec2 gridPosition)
{
	return abs(rand2(gridPosition) / 2);
}

vec3 distanceField(vec2 center, float radius, vec2 position) 
{
	return vec3(smoothstep(0, radius, distance(center, position)));
}

vec3 distanceWithRandomCenter(float radius, vec2 gridPosition, vec2 position) 
{
	return distanceField(randomPositionFromGridPosition(gridPosition), radius, position);
}

float min3(vec3 vec)
{
	return min(min(vec.x, vec.y), vec.z);
}

float minMat3(mat3 matrix)
{
	return min3(vec3(min3(matrix[0]), min3(matrix[1]), min3(matrix[2])));
}

vec3 unionOfDistanceFields(vec2 gridPosition, vec2 position) 
{
	vec2 currentCenter = randomPositionFromGridPosition(gridPosition);
	mat3 minimas;
	for(int x = -1; x <= 1; x++) 
	{
		for(int y = -1; y <= 1; y++) 
		{
			vec2 otherCenter = randomPositionFromGridPosition(gridPosition + vec2(x, y)) + vec2(x, y);
			float distanceToOtherCenter = abs(distance(otherCenter, position));
			minimas[x + 1][y + 1] = distanceToOtherCenter;
		}
	}
	return vec3(minMat3(minimas));
}

vec3 colorDistanceFields(vec2 gridPosition, vec2 position)
{
	vec2 currentCenter = randomPositionFromGridPosition(gridPosition);
	float minimum = 1;
	vec2 closestCenter;
	for(int x = -1; x <= 1; x++) 
	{
		for(int y = -1; y <= 1; y++) 
		{
			vec2 otherCenter = randomPositionFromGridPosition(gridPosition + vec2(x, y)) + vec2(x, y);
			float distanceToOtherCenter = abs(distance(otherCenter, position));
			if (minimum > distanceToOtherCenter)
			{
				minimum = distanceToOtherCenter;
				closestCenter = gridPosition + vec2(x, y);
			}
		}
	}
	return vec3(rand(closestCenter.x + closestCenter.y * 5), rand(closestCenter.x * 5 + closestCenter.y), rand(closestCenter.x * 5 + closestCenter.y * 5));
}

vec2 getRotatingCenterPosition(vec2 gridPosition) 
{
	vec2 center = vec2(.5);
	center.x += (cos(rand(gridPosition.yx) * 5 * rand(gridPosition) + iGlobalTime)) / 2;
	center.y += (sin(rand(gridPosition.yx) * 5 * rand(gridPosition) + iGlobalTime)) / 2;
	return center;
}

vec3 animatedUnionDistanceField(vec2 gridPosition, vec2 position) 
{
	vec2 currentCenter = getRotatingCenterPosition(gridPosition);
	mat3 minimas;
	for(int x = -1; x <= 1; x++) 
	{
		for(int y = -1; y <= 1; y++) 
		{
			vec2 otherCenter = getRotatingCenterPosition(gridPosition + vec2(x, y)) + vec2(x, y);
			float distanceToOtherCenter = abs(distance(otherCenter, position));
			minimas[x + 1][y + 1] = distanceToOtherCenter;
		}
	}
	return vec3(minMat3(minimas));
}

vec3 animatedColorDistanceField(vec2 gridPosition, vec2 position) 
{
	vec2 currentCenter = getRotatingCenterPosition(gridPosition);
	float minimum = 1;
	vec2 closestCenter;
	for(int x = -1; x <= 1; x++) 
	{
		for(int y = -1; y <= 1; y++) 
		{
			vec2 otherCenter = getRotatingCenterPosition(gridPosition + vec2(x, y)) + vec2(x, y);
			float distanceToOtherCenter = abs(distance(otherCenter, position));
			if (minimum > distanceToOtherCenter)
			{
				minimum = distanceToOtherCenter;
				closestCenter = gridPosition + vec2(x, y);
			}
		}
	}
	return vec3(rand(closestCenter.x + closestCenter.y * 5), rand(closestCenter.x * 5 + closestCenter.y), rand(closestCenter.x * 5 + closestCenter.y * 5));
}

void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);

	uv *= 5;

	//color.rgb = distanceField(vec2(.5), .5, fract(uv));

	//color.rgb = distanceWithRandomCenter(.5, vec2(floor(uv)), fract(uv));
	
	//color.rgb = unionOfDistanceFields(vec2(floor(uv)), fract(uv));
	
	//vec3 centers = distanceWithRandomCenter(.1, vec2(floor(uv)), fract(uv));

	//color.r = 1 - centers.r;
	
	//color.rgb = colorDistanceFields(floor(uv), fract(uv));

	//color.rgb = animatedUnionDistanceField(floor(uv), fract(uv));

	color.rgb = animatedColorDistanceField(floor(uv), fract(uv));
	
	//vec2 center = getRotatingCenterPosition(vec2(0));

	//color.rgb = distanceField(center, .2, uv);
	

	/*
	vec2 center0 = randomPositionFromGridPosition(vec2(0));
	vec2 center1 = randomPositionFromGridPosition(vec2(1));
	
	color.rgb = distanceField(center0, .5, uv);
	color.rgb *= distanceField(center1, .5, uv);

	color.rgb = vec3(min(distance(center0, uv), distance(center1, uv)));
	*/

	//color.rgb = vec3(floor(uv.x) / 5, floor(uv.y) / 5, 0);

	gl_FragColor = color;
}