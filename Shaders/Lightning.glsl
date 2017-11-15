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
	int mat;
	vec3 center;
	float radius;
};


vec3 GetColorOfSphere(struct LightSource source, vec3 ambientLight, struct Sphere sphere, struct Ray ray, vec3 hitPoint, struct Material mat)
{
	vec3 sphereNormal = normalize(hitPoint - sphere.center);
	vec3 lightDirection = normalize(source.position - hitPoint);
	vec3 reflectDirection = normalize(reflect(lightDirection, sphereNormal));

	float lightHitsForeground = step(0, dot(sphereNormal, lightDirection));
	float specularReflectionIsAbove90Deg = step(0, dot(reflectDirection, ray.direction));

	//Ambient
	vec3 sphereAmbientColor = mat.color * ambientLight;

	//Diffuse
	vec3 sphereDiffuseColor = mat.color * source.color * dot(sphereNormal, lightDirection) * lightHitsForeground;

	//Specular
	float specularAngle = dot(reflectDirection, ray.direction) * specularReflectionIsAbove90Deg * lightHitsForeground;
	vec3 sphereSpecularColor = source.color * pow(specularAngle, mat.shininess);

	return sphereAmbientColor + sphereDiffuseColor + sphereSpecularColor;
}
