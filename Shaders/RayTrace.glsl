#version 330


#define PI 3.1415

#include "Lightning.glsl"

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

struct LightSource 
{
	vec3 position;
	vec3 color;
};

struct Material {
	vec3 color;
	float shininess;
};

struct Ray {
	vec3 origin;
	vec3 direction;
};

struct Triangle {
	struct Material mat;
	vec3 pointA;
	vec3 pointB;
	vec3 pointC;
};

struct Plane {
	struct Material mat;
	vec3 normal;
	float dist;
};

struct Sphere {
	struct Material mat;
	vec3 center;
	float radius;
};

bool rayCastTriangle(struct Ray ray, struct Triangle triangle, out vec3 hit) 
{
	const float threshold = 0.01;
	vec3 E1 = triangle.pointB - triangle.pointA;
	vec3 E2 = triangle.pointC - triangle.pointA;

	vec3 P = cross(ray.direction, E2);
	float detM = dot(P, E1);
	if(abs(detM) > threshold) 
	{
		return false;
	}

	float f = 1 / detM;
	vec3 S = ray.origin - triangle.pointA;
	float u = f * dot(P, S);
	if(u < 0 || u > 1) 
	{
		return false;
	}

	vec3 Q = cross(S, E1);
	float v = f * dot(Q, ray.direction);
	if(v < 0 || u+v > 1) 
	{
		return false;
	}
	float t = f * dot(Q, E2);

	hit.x = t;
	hit.y = u;
	hit.z = v;

	return true;
}

float rayCastPlane(struct Plane plane, struct Ray ray) 
{
	float denom = dot(plane.normal, ray.direction);
	if(abs(denom) < 0.01)
	{
	//no intersection
	return -10000000000.;
	}
	return (-plane.dist - dot(plane.normal, ray.origin)) / denom;
}

vec2 rayCastSphere(struct Sphere sphere, struct Ray ray) 
{
	const float noSolution = -100000000.;
	vec3 OC = ray.origin - sphere.center;

	float OCd = dot(OC, ray.direction);

	float detM = pow(OCd, 2) - (dot(OC, OC) - pow(sphere.radius, 2));

	vec2 solutions = vec2(noSolution);
	if(detM > 0) 
	{
		//Two solutions
		solutions.x = -OCd + sqrt(detM);
		solutions.y = -OCd - sqrt(detM);
	}
	else if(detM == 0)
	{
		//One solution
		solutions.x = -OCd + sqrt(detM);
	}
	else 
	{
		//No solution
	}

	return solutions;
}

float findNearestSolutionOfRaycast(vec2 solutions) 
{
	float hasSolutionOne = step(0, solutions.x);
	float hasSolutionTwo = step(0, solutions.y);

	float nearestSolution = hasSolutionOne * hasSolutionTwo * (min(solutions.x, solutions.y)) +
							hasSolutionOne * (1 - hasSolutionTwo) * solutions.x +
							(1 - hasSolutionOne) * hasSolutionTwo * solutions.x;

	return nearestSolution;
}

bool isInShadow(vec3 hitPoint, vec3 lightSourcePosition, struct Sphere[4] spheres, int currentSphere) 
{
	vec3 sphereNormal = hitPoint - spheres[currentSphere].center;
	vec3 shadowPoint = hitPoint + sphereNormal * .01f;
	vec3 pointToLight = shadowPoint - lightSourcePosition;
	struct Ray ray = struct Ray(shadowPoint, pointToLight);

	for(int i = 0; i < 4; i++)
	{
		vec2 solutions = rayCastSphere(spheres[i], ray);

		if(solutions.x > 0 || solutions.y > 0) 
		{
			return false;
		}
	}
	return true;
}

vec3 spheresWithLightning(struct Sphere[4] spheres, struct Ray ray, struct LightSource lightSource) 
{
	vec3 returns;
	for(int i = 0; i < 4; i++) 
	{
		vec2 solutions = rayCastSphere(spheres[i], ray);

		float nearestSolution = findNearestSolutionOfRaycast(solutions);

		float hitSphere = step(0.0000001, nearestSolution);
		vec3 hitPoint = ray.origin + ray.direction * nearestSolution;

		returns += hitSphere * GetColorOfSphere(lightSource, spheres[i], ray, hitPoint);
		
		if(hitSphere == 1) 
		{
			if(isInShadow(hitPoint, lightSource.position, spheres, i))
			{
				returns = vec3(1, 1, 1);
			}
		}

	}

	return returns;
}


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
	vec2 uv = gl_FragCoord.xy / iResolution.xy;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);
	
	float fov = .1 * PI;
	struct Ray ray = GetCameraRay(vec3(0), fov, gl_FragCoord.xy, iResolution);

	struct LightSource lightSource;
	lightSource.position = vec3(0, 10, 30); 
	lightSource.color = vec3(.4);

	
	/*
	//Triangle
	struct Triangle triangle;
	triangle.pointA = vec3(0, 0, 1);
	triangle.pointB = vec3(0, 1, 1);
	triangle.pointC = vec3(1, 0, 1);

	vec3 hit;
	bool bHit;
	bHit = rayCastTriangle(ray, triangle, hit);

	if(bHit)
	{
		color.rgb = vec3(0, 0, 0);
	}
	*/
	

	/*
	//Plane
	struct Plane plane;
	plane.normal = normalize(vec3(0, 1, 0));
	plane.dist = 0;


	color.rgb = vec3(rayCastPlane(plane, ray) > 0 ? 1.0 : 0.0 );
	*/

	//color.rgb = abs(ray.direction);


	//Sphere
	struct Sphere sphere1;
	sphere1.center = vec3(-3, 0, 30);
	sphere1.radius = .6f;
	sphere1.mat = struct Material(vec3(1, 0, 0), 8f);

	struct Sphere sphere2;
	sphere2.center = vec3(0, 1, 30);
	sphere2.radius = .6f;
	sphere2.mat = struct Material(vec3(0, 1, 0), 8f);
	
	struct Sphere sphere3;
	sphere3.center = vec3(3, 0, 30);
	sphere3.radius = .6f;
	sphere3.mat = struct Material(vec3(0, 0, 1), 8f);

	struct Sphere sphere4;
	sphere4.center = vec3(1, -1.5, 30);
	sphere4.radius = .6f;
	sphere4.mat = struct Material(vec3(1, 0, 1), 8f);

	struct Sphere[4] spheres;
	spheres[0] = sphere1;
	spheres[1] = sphere2;
	spheres[2] = sphere3;
	spheres[3] = sphere4;
	
	color.rgb = spheresWithLightning(spheres, ray, lightSource);
	//color.rgb += sphereWithLightning(sphere2, ray, lightSource);
	//color.rgb += sphereWithLightning(sphere3, ray, lightSource);
	//color.rgb += sphereWithLightning(sphere4, ray, lightSource);


	
	gl_FragColor = color;
}
