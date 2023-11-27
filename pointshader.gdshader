shader_type spatial;
render_mode world_vertex_coords, shadows_disabled;

// parameters set for each octree node according to depth and displacement
uniform float point_scale = 14.0;
uniform sampler2D position_noise;

// distance shading parameters
const vec3 closecol = vec3(1,0,0);
const vec3 farcol = vec3(0,0,1);
const float fardist = 30.0;
const float fardisttaper = 20.0;
const float fardisttaperfac = -(fardisttaper*((fardisttaper + fardist)))/fardist;


// parameters defining the colour across face of each scatter point
const vec3 bordercolor = vec3(0.1, 0.1, 0.2);
const float edgeborder = 0.5 - 0.05; 
const float closenessdist = 0.3;

// parameters carried from vertext shader into the fragment shader
varying vec3 emissioncol;
varying vec3 bordercol; 
varying float edgebord; 
varying float closenessfrac;
uniform float colormixweight = 0.5; 

void vertex() {
	float distcamera = length(CAMERA_POSITION_WORLD - VERTEX); 
	POINT_SIZE = point_scale/distcamera;
	closenessfrac = 1.0 - distcamera/closenessdist;
	//NORMAL = -CAMERA_DIRECTION_WORLD;
	NORMAL = normalize(CAMERA_POSITION_WORLD - VERTEX);
	
	float mixval = (1.0/(distcamera + fardisttaper) - 1.0/fardisttaper)*fardisttaperfac;
	vec3 distancecolor = mix(closecol, farcol, mixval);
	COLOR.rgb = mix(distancecolor, COLOR.rgb, colormixweight);
	
//	VERTEX.x += sin(TIME * float(VERTEX_ID + 100)/100.0)*0.02;
//	VERTEX.y += cos(TIME * float(VERTEX_ID + 100)/100.0)*0.02;
	
	vec4 normnoise = texture(position_noise, vec2(TIME*0.001+VERTEX.x*120.1, VERTEX.y*320.1 + VERTEX.z*23.03)); 
	VERTEX.xyz += vec3((normnoise.x-0.5), (normnoise.z-0.99)*20.0, (normnoise.y-0.5)); 
}

void fragment() {
	float rsq = (POINT_COORD.x-0.5)*(POINT_COORD.x-0.5) + (POINT_COORD.y-0.5)*(POINT_COORD.y-0.5);
	if (rsq > 0.25+point_scale*0.002) 
		discard;

	ALPHA = 0.15*mix(1.0, 0.0, rsq*4.0);
	ALBEDO *= mix(COLOR.xyz, bordercolor, rsq*3.0);
	if (closenessfrac > 0.0) {
		if ((abs(POINT_COORD.x*2.0-1.0) < closenessfrac) || (abs(POINT_COORD.y*2.0-1.0) < closenessfrac))
			discard; 
	}
//	METALLIC = 1.0;
//	ROUGHNESS = 0.0; 
//	NORMAL = normalize(vec3(POINT_COORD.y - 0.5, POINT_COORD.x - 0.5, 1.1));
}
