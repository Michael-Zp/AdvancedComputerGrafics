#version 330


#define PI 3.1415

#include "Lightning.glsl"

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]


const vec3 ambientLight = vec3(.1);
struct LightSource 
{
	vec3 position;
	vec3 color;
};

struct Material
{
	vec3 color;
	float shininess;
};

struct Ray 
{
	vec3 origin;
	vec3 direction;
};

const int NoHitType = -1;

const int TriangleType = 0;
struct Triangle 
{
	int mat;
	vec3 pointA;
	vec3 pointB;
	vec3 pointC;
};

const int PlaneType = 1;
struct Plane 
{
	int mat;
	vec3 normal;
	float dist;
};

const int SphereType = 2;
struct Sphere 
{
	int mat;
	vec3 center;
	float radius;
};

struct RayCastSolution 
{
	int mat;
	int type;
	float dist;
	int index;
	vec3 normal;
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

#define SPHERE_COUNT 4
#define PLANE_COUNT 1
#define MATERIAL_COUNT 5

bool isInShadow(vec3 shadowPoint, vec3 lightSourcePosition, struct Sphere[SPHERE_COUNT] spheres) 
{
	vec3 pointToLight = normalize(lightSourcePosition - shadowPoint);
	struct Ray ray = struct Ray(shadowPoint, pointToLight);

	for(int i = 0; i < SPHERE_COUNT; i++)
	{
		vec2 solutions = rayCastSphere(spheres[i], ray);

		if(solutions.x > 0 || solutions.y > 0) 
		{
			return true;
		}
	}
	return false;
}

vec3 spheresWithLightning(struct Sphere[SPHERE_COUNT] spheres, vec3 ambientLight, struct Ray ray, struct LightSource lightSource, struct Material mat) 
{
	vec3 returns;
	for(int i = 0; i < SPHERE_COUNT; i++) 
	{
		vec2 solutions = rayCastSphere(spheres[i], ray);

		float nearestSolution = findNearestSolutionOfRaycast(solutions);

		float hitSphere = step(0.0000001, nearestSolution);
		vec3 hitPoint = ray.origin + ray.direction * nearestSolution;

		returns += hitSphere * GetColorOfSphere(lightSource, ambientLight, spheres[i], ray, hitPoint, mat);
	}

	return returns;
}

struct RayCastSolution rayCastAll(struct Sphere[SPHERE_COUNT] spheres, struct Plane[PLANE_COUNT] planes, struct Ray ray) 
{
	struct RayCastSolution solution;

	float sphereDistance = 10000000;
	for(int i = 0; i < SPHERE_COUNT; i++) 
	{
		vec2 solutions = rayCastSphere(spheres[i], ray);

		float tempNearestSol = findNearestSolutionOfRaycast(solutions);

		if(tempNearestSol < sphereDistance && tempNearestSol > 0) 
		{
			sphereDistance = tempNearestSol;
			solution.mat = spheres[i].mat;
			solution.index = i;
		}
	}

	float planeDistance = rayCastPlane(planes[0], ray);

	float hitPlane = step(0.0000001, planeDistance);
	float hitSphere = step(0.0000001, sphereDistance);

	if(planeDistance < sphereDistance && hitPlane == 1) 
	{
		solution.type = PlaneType;
		solution.dist = planeDistance;
		solution.index = 0;
		solution.normal = planes[solution.index].normal;
	}
	else if(hitSphere == 1 && sphereDistance != 10000000) 
	{
		solution.type = SphereType;
		solution.dist = sphereDistance;
		vec3 hitPoint = ray.origin + ray.direction * sphereDistance;
		solution.normal = normalize(hitPoint - spheres[solution.index].center);
	}
	else 
	{
		solution.type = NoHitType;
		solution.dist = -10000000;
	}

	if(solution.dist > 1000) 
	{
		solution.type = NoHitType;
		solution.dist = -10000000;
	}

	return solution;
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
	struct Ray ray = GetCameraRay(vec3(0, 1, 0), fov, gl_FragCoord.xy, iResolution);
	
	struct LightSource lightSource;
	lightSource.position = vec3(-10, 10, 0); 
	lightSource.color = vec3(1);
	 
	
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
	
	struct Material[MATERIAL_COUNT] materials;
	materials[0] = struct Material(vec3(.5), 8f);
	materials[1] = struct Material(vec3(1, 0, 0), 8f);
	materials[2] = struct Material(vec3(0, 1, 0), 8f);
	materials[3] = struct Material(vec3(0, 0, 1), 8f);
	materials[4] = struct Material(vec3(1, 0, 1), 8f);
		

	struct Plane[PLANE_COUNT] planes;
	planes[0].dist = 0;
	planes[0].normal = normalize(vec3(0, 1, 0));
	planes[0].mat = 0;

	//Sphere
	struct Sphere sphere1;
	sphere1.center = vec3(0, 1, 20);
	sphere1.radius = .6f;
	sphere1.mat = 1;

	struct Sphere sphere2;
	sphere2.center = vec3(-1, 1, 22.5);
	sphere2.radius = .6f;
	sphere2.mat = 2;
	
	struct Sphere sphere3;
	sphere3.center = vec3(0, 1, 25);
	sphere3.radius = .6f;
	sphere3.mat = 3;

	
	struct Sphere sphere4;
	sphere4.center = vec3(1, 1, 22.5);
	sphere4.radius = .6f;
	sphere4.mat = 4;
	

	struct Sphere[SPHERE_COUNT] spheres;
	spheres[0] = sphere1;
	spheres[1] = sphere2;
	spheres[2] = sphere3;
	spheres[3] = sphere4;


	struct RayCastSolution solution = rayCastAll(spheres, planes, ray);
	vec3 hitPoint = ray.origin + ray.direction * solution.dist;

	switch(solution.type) {
		case NoHitType:
			color.rgb += vec3(1);
			break;

		case TriangleType:
			break;

		case PlaneType:
			color.rgb = materials[solution.mat].color;
			break;

		case SphereType:
			color.rgb = GetColorOfSphere(lightSource, ambientLight, spheres[solution.index], ray, hitPoint, materials[solution.mat]);
			break;

		default:
			color.rgb = vec3(1);
	}
	
	const float epsilon = 0.001f;
		
	vec3 shadowPoint = hitPoint + epsilon * solution.normal;
	
	float hasSolution = step(epsilon, solution.dist);
	bool bIsInShadow = isInShadow(shadowPoint, lightSource.position, spheres);

	color.rgb = hasSolution * (bIsInShadow ? ambientLight : color.rgb)
				+ (1 - hasSolution) * vec3(0f);


	const int RECURSIONS = 3;
	for(int i = 0; i < RECURSIONS; i++)
	{
		vec3 hitPoint = ray.origin + ray.direction * solution.dist;

		ray.origin = hitPoint + epsilon * solution.normal;
		ray.direction = reflect(ray.direction, solution.normal);

		solution = rayCastAll(spheres, planes, ray);
		switch(solution.type) {
			case NoHitType:
				color.rgb += vec3(0);
				break;

			case TriangleType:
				break;

			case PlaneType:
				color.rgb += materials[solution.mat].color * .3;
				break;

			case SphereType:
				color.rgb += GetColorOfSphere(lightSource, ambientLight, spheres[solution.index], ray, hitPoint, materials[solution.mat]);
				break;

			default:
				color.rgb += vec3(0);
		}
	}

	const float BrechzahlMedium1 = 1;		//Luft
	const float BrechzahlMedium2 = 1.46;	//Glas


	for(int i = 0; i < RECURSIONS; i++) 
	{
		vec3 hitPoint = ray.origin + ray.direction * solution.dist;

		ray.origin = hitPoint - epsilon * solution.normal;


		ray.direction = refract(ray.direction, solution.normal, 
	}

	gl_FragColor = color;
}
