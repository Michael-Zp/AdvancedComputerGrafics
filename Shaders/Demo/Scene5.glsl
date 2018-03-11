#version 330

#include "../libs/camera.glsl"
#include "../libs/Noise.glsl"

struct LightSource 
{
	vec3 position;
	vec3 color;
};


uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform float orthogonal;
uniform float shouldRotate;
uniform float lightIntensity;

float localTime = iGlobalTime - 34.0;


float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

float sdCylinder( vec3 point, vec3 cylinder )
{
  	return length(point.xz - cylinder.xy) - cylinder.z;
}

float udBox( vec3 point, vec3 box )
{
  return length(max(abs(point) - box, 0.0));
}

float opUnify(float a, float b)
{
	return min(a, b);
}

float opIntersect( float a, float b )
{
    return max(a, b);
}

float opBlend( float a, float b )
{
    return smin( a, b, 0.05 );
}


vec3 GetColor(LightSource source, vec3 ambientLight, vec3 hitPoint, vec3 normal, vec3 camDir, vec3 color, float shininess)
{
	vec3 lightDirection = normalize(source.position - hitPoint);
	vec3 reflectDirection = normalize(reflect(lightDirection, normal));

	float lightHitsForeground = step(0, dot(normal, lightDirection));
	float specularReflectionIsAbove90Deg = step(0, dot(reflectDirection, camDir));

	//Ambient
	vec3 sphereAmbientColor = color * ambientLight;

	//Diffuse
	vec3 sphereDiffuseColor = color * source.color * dot(normal, lightDirection) * lightHitsForeground;

	//Specular
	float specularAngle = dot(reflectDirection, camDir) * specularReflectionIsAbove90Deg * lightHitsForeground;
	vec3 sphereSpecularColor = source.color * pow(specularAngle, shininess);

	return sphereAmbientColor + sphereDiffuseColor + sphereSpecularColor;
}

float map(vec3, out float, out float);

vec3 getNormal(vec3 hitPoint, float delta)
{
	vec2 deltaVec = vec2(delta, 0);

	float notRelevant;

	float nextX = map(hitPoint + deltaVec.xyy, notRelevant, notRelevant);
	float nextY = map(hitPoint + deltaVec.yxy, notRelevant, notRelevant);
	float nextZ = map(hitPoint + deltaVec.yyx, notRelevant, notRelevant);

	float previousX = map(hitPoint - deltaVec.xyy, notRelevant, notRelevant);
	float previousY = map(hitPoint - deltaVec.yxy, notRelevant, notRelevant);
	float previousZ = map(hitPoint - deltaVec.yyx, notRelevant, notRelevant);

	vec3 unnormalizedGradient = vec3(nextX - previousX, nextY - previousY, nextZ - previousZ);

	return normalize(unnormalizedGradient);
}

float generateTimeRestriction(float seconds)
{
	return (1 - step(seconds, localTime)) * 100;
}


//Model parameters
const float PI = 3.1415;
const float stretch = 0.5; 
const float size = 0.25;
const float smallSize = size / 12.0;
const float horizontalInterval = 0.1;
const float thickness = 0.1;

float mapDNA(vec3 rayPos, out float hitId, out float horizontalId, float helixOnePlacement, float helixTwoPlacement, float innerOnePlacement, float innerTwoPlacement, float speed, float axisAngle, float seed)
{
	float axisC = cos(axisAngle);
	float axisS = sin(axisAngle);

	rayPos.xy = mat2(axisC, axisS, -axisS, axisC) * rayPos.xy;

	float zId = floor((rayPos.z + 5.0) / 5.0);

	rayPos.z = mod(rayPos.z + 5, 5) - 2.5;

	horizontalId = floor(rayPos.y / horizontalInterval);


	//Model stuff
	float rotationAngle = rayPos.y / stretch + (localTime * rand(zId * zId + seed)) * shouldRotate;

	float yRotateC = cos(rotationAngle);
	float yRotateS = sin(rotationAngle);

	float xPos = yRotateC * size;
	float zPos = yRotateS * size;

	float helixOne = sdCylinder(rayPos, vec3(xPos, zPos, thickness));
	float helixTwo = sdCylinder(rayPos, vec3(-xPos, -zPos, thickness));

	//Splitt inner things in to cylinders to have more freedom. Would be better to intersect with boxes, but works also with cylinders
	float innerCylinderOne = sdCylinder(rayPos, vec3(xPos / 2, zPos / 2, size / 2));
	float innerCylinderTwo = sdCylinder(rayPos, vec3(-xPos / 2, -zPos / 2, size / 2));

	vec3 horizontalPos = vec3(mod(rayPos.y, horizontalInterval) - horizontalInterval / 2.0, rayPos.x, rayPos.z);

	float angle = PI - rotationAngle;
	float c = cos(angle);
	float s = sin(angle);

	horizontalPos.yz = mat2(c, s, -s, c) * horizontalPos.yz;

	float horizontalCylinder = sdCylinder(horizontalPos, vec3(0, 0, smallSize));


	//Switch stuff
	const float smoothness = 1;
	float speedUpTime = localTime * speed;


	helixOne += smoothstep(helixOnePlacement + speedUpTime, helixOnePlacement + speedUpTime + smoothness, rayPos.y);
	helixTwo += smoothstep(helixTwoPlacement + speedUpTime, helixTwoPlacement + speedUpTime + smoothness, rayPos.y);
	innerCylinderOne += smoothstep(innerOnePlacement + speedUpTime, innerOnePlacement + speedUpTime + smoothness, rayPos.y);
	innerCylinderTwo += smoothstep(innerTwoPlacement + speedUpTime, innerTwoPlacement + speedUpTime + smoothness, rayPos.y);
	
	//Concatenate stuff
	float inner = opUnify(opIntersect(horizontalCylinder, innerCylinderOne), opIntersect(horizontalCylinder, innerCylinderTwo));
	float outer = opUnify(helixOne, helixTwo);

	float hitInner = step(inner, outer);
	float hitCylinderTwo = step(innerCylinderTwo, innerCylinderOne);

	hitId = hitInner * 2 + hitCylinderTwo;


	return opBlend(inner, outer);
}

float map(vec3 rayPos, out float hitId, out float horizontalId)
{	
	const int helixCount = 3;
	float[helixCount] hitIds;
	float[helixCount] horizontalIds;
	float[helixCount] distances;

	distances[0] = mapDNA(rayPos, hitIds[0], horizontalIds[0], -2.5, -4.5, -3.5, -5.5, 3, 0, 0);
	distances[1] = mapDNA(rayPos - vec3(1.5, 0, 0), hitIds[1], horizontalIds[1], -5.5, -7.5, -6.5, -8.5, 4.5, 0, 1);
	distances[2] = mapDNA(rayPos - vec3(-1.5, 0, 0), hitIds[2], horizontalIds[2], -5.5, -7.5, -6.5, -8.5, 4.5, 0, 2);

	float zeroSmallerOne = step(distances[0], distances[1]);
	float zeroSmallerTwo = step(distances[0], distances[2]);
	float oneSmallerZero = step(distances[1], distances[0]);
	float oneSmallerTwo = step(distances[1], distances[2]);
	float twoSmallerZero = step(distances[2], distances[0]);
	float twoSmallerOne = step(distances[2], distances[1]);


	int minIndex = int(
		step(0.5, zeroSmallerOne) * step(0.5, zeroSmallerTwo) * 0.0 + 
		step(0.5, oneSmallerZero) * step(0.5, oneSmallerTwo) * 1.0 +
		step(0.5, twoSmallerZero) * step(0.5, twoSmallerOne) * 2.0
	);

	hitId = hitIds[minIndex];
	horizontalId = horizontalIds[minIndex];

	return distances[minIndex];
}




vec3 drawScene(vec3 camPos, vec3 camDir)
{
	LightSource light;
	light.position = vec3(0, 10, -15);
	light.color = vec3(1, 1, 1);

	const float EPSILON = 1e-5;
	const int Steps = 156;
	const float maxDist = 100;

	vec3 color = vec3(0);

	vec3 rayPos = camPos;
	float dist = 0;
	float distanceToObj = 0;
	float hitId = -1;
	float horizontalId = -1;
	for(int t = 0; t < Steps; t++)
	{
		distanceToObj = map(rayPos, hitId, horizontalId);
		if(distanceToObj < EPSILON)
		{
			rayPos += distanceToObj * camDir;
			color.rgb = vec3(1);

			vec3[4] colors = vec3[4] (
				vec3(1, 0, 0),
				vec3(0, 1, 0),
				vec3(0, 0, 1),
				vec3(1, 1, 0)
			);

			if(hitId > 1.5) //Hit inner
			{
				if(hitId > 2.5) //Hit inner cylinder 1
				{
					float id = rand(horizontalId) * 4;
					color = colors[int(id)];
				}
				else //Hit inner cylinder 2
				{
					float id = rand(horizontalId + 100) * 4;
					color = colors[int(id)];
				}
			}
			
			vec3 colorWithLight = GetColor(light, vec3(.1), rayPos, getNormal(rayPos, 1e-5), camDir, color.rgb, 16.0);

			color.rgb = mix(color, colorWithLight, lightIntensity);

			break;
		}

		float maxDistSmallerDist = step(maxDist, dist);
		t = t + int(maxDistSmallerDist * Steps);

		//Not going the whole distance reduces performance, but prefents artifacts
		rayPos += (distanceToObj * .75) * camDir;
		dist += distanceToObj;
	}

	return color;
}

void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution;

	//4 component color red, green, blue, alpha
	vec4 color = vec4(0, 0, 0, 1);

	vec3 camP = vec3(0);
	vec3 camDir = vec3(0);
	
	const vec2 pixelResolution = vec2(2);
	for(int x = 0; x < pixelResolution.x; x++) 
	{
		for(int y = 0; y < pixelResolution.y; y++)
		{
			const float size = 5;
			const float zOffset = 5;

			vec2 coordPos = vec2(gl_FragCoord.x + x * (1.0 / pixelResolution.x), gl_FragCoord.y + y * (1.0 / pixelResolution.y));
			vec2 newUv = coordPos / iResolution;
			newUv.y /= iResolution.x / iResolution.y;

			vec3 orthCamP = vec3(newUv * size - size / 2.0, -zOffset);
			vec3 orthCamDir = vec3(0, 0, 1);
			
			const float fov = degrees(atan((size / 2.0) / zOffset)) * 2.0;
			vec3 perCamP = calcCameraPos();
			perCamP += vec3(0, 0, -zOffset);
			vec3 perCamDir = calcCameraRayDir(fov, coordPos, iResolution);
			
			camP = mix(perCamP, orthCamP, orthogonal);
			camDir = mix(perCamDir, orthCamDir, orthogonal);

			color.rgb += drawScene(camP, camDir);
		}
	}
	color.rgb /= (pixelResolution.x * pixelResolution.y);
	

	gl_FragColor = color;
}