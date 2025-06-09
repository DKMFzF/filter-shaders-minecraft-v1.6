#version 120

#define	shakingHand
float	weatherRatioSpeed		= 0.01;

varying vec4 color;
varying vec3 normal;
varying vec2 texcoord;
varying float weatherRatio;
varying float skyLightmap;
varying float torchLightmap;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform int worldTime;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int heldBlockLightValue;

// Calculate Time of Day.
float time = worldTime;
float TimeSunrise		= ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(time, 0.0, 3000.0)/3000.0));
float TimeNoon			= ((clamp(time, 0.0, 3000.0)) / 3000.0) - ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0);
float TimeSunset		= ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(time, 12000.0, 13000.0) - 12000.0) / 1000.0);
float TimeMidnight		= ((clamp(time, 12000.0, 13000.0) - 12000.0) / 1000.0) - ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0);
float TimeDay			= TimeSunrise + TimeNoon + TimeSunset;
float DayToNightFading	= 1.0 - (clamp((time - 12000.0) / 300.0, 0.0, 1.0) - clamp((time - 13000.0) / 300.0, 0.0, 1.0) 
							  +  clamp((time - 22800.0) / 200.0, 0.0, 1.0) - clamp((time - 23400.0) / 200.0, 0.0, 1.0));

float dynamicWeather(float speed) {
	
	float value = 1.0;
		  value *= abs(sin(frameTimeCounter * speed * 1.2));
		  value *= abs(cos(frameTimeCounter * speed * 0.5));
		  value *= abs(sin(frameTimeCounter * speed * 2.0));
	
	// Raining.
	value = mix(value, 1.0, rainStrength);
		  
	return value;
	
}

float getSkyLightmap(vec2 coord) {

	float minLight = 0.05;

	return clamp(minLight + max(coord.t - 2.0 / 16.0, 0.0) * 1.14285714286, 0.0, 1.0);

}

float getTorchLightmap(vec2 coord, float skyL) {

	float torchlightDistance = 0.6;	// Higher means lower.
	float torchlightExposure = 4.0;
	
	torchlightDistance = mix(torchlightDistance, torchlightDistance * 2.0, skyL * TimeDay);
	torchlightExposure = mix(torchlightExposure, torchlightExposure / 2.0, skyL * TimeDay);

	float modlmap = 16.0 - coord.s * 15.7; 

	return clamp(pow(0.75 / (modlmap * modlmap) - 0.00315, torchlightDistance), 0.0, 1.0) * torchlightExposure;

}

void main() {
	
	vec4 position		= gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex;
	vec2 lmcoord		= (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	vec3 sunVec			= normalize(sunPosition);
	vec3 upVec			= normalize(upPosition);
	
	normal				= normalize(gl_NormalMatrix * gl_Normal);
	texcoord			= (gl_MultiTexCoord0).xy;
		
	color = gl_Color;

	#ifdef shakingHand
		position.xy += vec2(0.01 * sin(frameTimeCounter), 0.01 * cos(frameTimeCounter * 2.0));
	#endif
	
	gl_Position = gl_ProjectionMatrix * gbufferModelView * position;
	
	#ifdef enableDynamicWeather
		weatherRatio = dynamicWeather(weatherRatioSpeed);
	#else
		weatherRatio = rainStrength;
	#endif
	
	skyLightmap = getSkyLightmap(lmcoord);
	torchLightmap = getTorchLightmap(lmcoord, skyLightmap);
	
}