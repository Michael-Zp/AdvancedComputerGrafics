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

struct Sphere {
	struct Material mat;
	vec3 center;
	float radius;
};


vec3 GetColorOfSphere(struct LightSource source, struct Sphere sphere, struct Ray ray, vec3 hitPoint)
{
	vec3 sphereNormal = hitPoint - sphere.center;
	vec3 lightDirection = source.position - hitPoint;
	vec3 reflectDirection = 1 - reflect(-lightDirection, sphereNormal);

	float lightHitsForeground = step(0, dot(sphereNormal, lightDirection));
	float specularReflectionIsAbove90Deg = step(0, dot(reflectDirection, ray.direction));

	vec3 sphereAmbientColor = sphere.mat.color * source.color;
	vec3 sphereDiffuseColor = sphere.mat.color * source.color * dot(sphereNormal, lightDirection) * lightHitsForeground;

	float specularAngle = dot(reflectDirection, ray.direction) * specularReflectionIsAbove90Deg * lightHitsForeground;
	vec3 sphereSpecularColor = sphere.mat.color * source.color * pow(specularAngle, sphere.mat.shininess);

	return sphereAmbientColor + sphereDiffuseColor + sphereSpecularColor;
}
