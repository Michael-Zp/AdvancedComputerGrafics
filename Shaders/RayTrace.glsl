#version 330

uniform vec2 iResolution; //[xResolution, yResolution] of display
uniform float iGlobalTime; //global time in seconds as float
uniform vec3 iMouse; //[xPosMouse, yPosMouse, isLeftMouseButtonClicked]

struct Ray {
	vec3 origin;
	vec3 direction;
};

struct Triangle {
	vec3 pointA;
	vec3 pointB;
	vec3 pointC;
};

struct Plane {
	vec3 normal;
	float dist;
};

struct Sphere {
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
	vec3 OC = ray.origin - sphere.center;

	float OCd = dot(OC, ray.direction);

	float detM = pow(OCd, 2) - (dot(OC, OC) - pow(sphere.radius, 2));

	vec2 solutions;
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
		solutions.y = -100000000.;
	}
	else 
	{
		//No solution
		solutions.x = -100000000.;
		solutions.y = -100000000.;
	}
	return solutions;
}

#define PI 3.1415

void main()
{
	//create uv to be in the range [0..1]x[0..1]
	vec2 uv = gl_FragCoord.xy / iResolution.xy;
	vec2 mouse = iMouse.xy / iResolution;
	//4 component color red, green, blue, alpha
	vec4 color = vec4(uv, 0, 1);
	
	//Camera Ray
	struct Ray ray;
	const float fov = 0.5 * PI;
	float fx = tan(fov / 2) / iResolution.x;
	vec2 d = (2 * gl_FragCoord.xy - iResolution) * fx;
	ray.direction = normalize(vec3(d, 1));
	ray.origin = vec3(0, 0, 0);


	
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
	struct Sphere sphere;
	sphere.center = vec3(1, 1, 1);
	sphere.radius = .1;
	vec2 solutions = rayCastSphere(sphere, ray);
	

	gl_FragColor = color;
}
