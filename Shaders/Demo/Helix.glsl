uniform float iGlobalTime;
uniform vec2 iResolution;
uniform vec3 iMouse;

vec3 LIGHT = normalize(vec3(-0.3,0.2,-0.1));

const float FULL_SIZE = 2.0;
const float EDGE_SIZE = 0.2;
const float PAIR_SIZE = 0.2;

vec3 model(vec3 position)
{
    float angle = position.z / 3.0 + iGlobalTime * 0.25;
    vec2 rotation = vec2(cos(angle), sin(angle));
    vec2 distanceToOuterHelix = vec2(mod(position.xy + 8., 16.) - 8. + rotation.yx * vec2(1, -1));
    
    float helix = min(length(distanceToOuterHelix + rotation.xy * FULL_SIZE), length(distanceToOuterHelix - rotation.xy * FULL_SIZE)) * 0.5 - EDGE_SIZE;
    float P = max(
                    length(vec2(dot(distanceToOuterHelix, rotation.yx * vec2(1, -1)), 0)) - PAIR_SIZE,

                    length(distanceToOuterHelix) - FULL_SIZE);

    float T = FULL_SIZE+0.01+2.*EDGE_SIZE-length(distanceToOuterHelix);
    return vec3(min(helix,P),T,P);  
}

vec3 normal(vec3 p)
{
 	vec2 N = vec2(-0.04, 0.04);

 	return normalize(model(p+N.xyy).x*N.xyy+model(p+N.yxy).x*N.yxy+
                     model(p+N.yyx).x*N.yyx+model(p+N.xxx).x*N.xxx);
}

vec4 raymarch(vec3 p, vec3 d)
{
    vec4 M = vec4(p+d*2.0,0);
 	for(int i = 0; i<100;i++)
    {
        float S = model(M.xyz).x;
    	M += vec4(d,1) * S;
        if (S<0.01 || M.w>50.0) break;
    }
    return M;
}

vec3 sky(vec3 d)
{
    float L = dot(d,LIGHT);
 	return vec3(0.3,0.5,0.6)-0.3*(-L*0.5+0.5)+exp2(32.0*(L-1.0));   
}

vec3 color(vec3 p, vec3 d)
{
    vec2 M = model(p).yz;
    float A = atan(mod(p.y+8.,16.)-8.,8.-mod(p.x+8.,16.));
    float T1 = ceil(fract(cos(floor(p.z)*274.63))-0.5);
    float T2 = sign(fract(cos(floor(p.z-80.0)*982.51))-0.5);
    float T3 = T2*sign(cos(p.z/3.0+iGlobalTime*0.25+A));

    float L = dot(normal(p),LIGHT)*0.5+0.5;
    float R = max(dot(reflect(d,normal(p)),LIGHT),0.0);
    vec3 C = mix(mix(vec3(0.9-0.8*T3,0.9-0.6*T3,T3),vec3(1.0-0.6*T3,0.2+0.8*T3,0.1*T3),T1),vec3(0.2),step(0.01,M.y));
 	C = mix(C,vec3(0.2,0.5,1.0),step(0.01,-M.x));
    return	C*L+pow(R,16.0);
}
void main()
{
    //Camera
    vec2 A = vec2(0, 0);
    vec3 D = vec3(cos(A.x)*sin(A.y),sin(A.x)*sin(A.y),cos(A.y));
    D = mix(vec3(1,0,0),D,ceil((A.x+A.y)/10.0));
    vec3 P = D*12.0-vec3(0,0,iGlobalTime*2.0);
    
    vec3 X = normalize(-D);
    vec3 Y = normalize(cross(X,vec3(0,0,1)));
    vec3 Z = normalize(cross(X,Y));
    
	vec2 UV = (gl_FragCoord.xy - iResolution.xy * 0.5) / iResolution.y;
    vec3 R = normalize(mat3(X,Y,Z) * vec3(1,UV));
    
    vec4 M = raymarch(P,R);
    vec3 C = mix(color(M.xyz,R),sky(R),smoothstep(0.5,1.0,M.w/50.0));
	gl_FragColor = vec4(C,1);
}