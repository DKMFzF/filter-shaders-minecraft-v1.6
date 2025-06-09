#version 120


#define	useDynamicTonemapping

varying vec4 color;
varying vec3 normal;
varying vec2 texcoord;
varying float weatherRatio;
varying float skyLightmap;
varying float torchLightmap;

uniform sampler2D texture;
uniform sampler2DShadow shadow;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int fogMode;
uniform int worldTime;
uniform float wetness;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;

uniform int heldBlockLightValue;
uniform int isEyeInWater;

float time = worldTime;
float TimeSunrise		= ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(time, 0.0, 3000.0)/3000.0));
float TimeNoon			= ((clamp(time, 0.0, 3000.0)) / 3000.0) - ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0);
float TimeSunset		= ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight		= ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0);
float TimeDay			= TimeSunrise + TimeNoon + TimeSunset;
float DayToNightFading	= 1.0 - (clamp((time - 12000.0) / 300.0, 0.0, 1.0) - clamp((time - 13000.0) / 300.0, 0.0, 1.0)
							  +  clamp((time - 22800.0) / 200.0, 0.0, 1.0) - clamp((time - 23400.0) / 200.0, 0.0, 1.0));

float dynamicTonemapping(float exposureStrength, bool reserveLightmap, bool addExposure, bool dayOnly) {

	float dTonemap = 1.0;

	#ifdef useDynamicTonemapping
	
		float dTlightmap	= pow(eyeBrightnessSmooth.y / 240.0, 2.0);		if (reserveLightmap)	dTlightmap 	= 1.0 - dTlightmap;
			  dTonemap		= dTlightmap * exposureStrength;				if (addExposure)		dTonemap	= 1.0 + dTonemap;		if (dayOnly)	dTonemap = mix(dTonemap, 1.0, TimeMidnight);	// Full exposure on midnight.

	#endif
	
	return dTonemap;

}


void main() {

	vec4 baseColor = texture2D(texture, texcoord.xy) * color;


	vec4 fragposition	= gbufferProjectionInverse * (vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight), gl_FragCoord.z, 1.0) * 2.0 - 1.0);
	vec4 worldposition	= gbufferModelViewInverse * fragposition;

	float ambientStrength		= 0.8;
	float sunlightStrength		= 1.3;

	vec3 ambient_Color  = vec3(0.0);
		 ambient_Color += vec3(0.75, 0.8, 1.0)	* 0.6	* TimeSunrise;
		 ambient_Color += vec3(0.75, 0.8, 1.0)			* TimeNoon;
		 ambient_Color += vec3(0.75, 0.8, 1.0)	* 0.6	* TimeSunset;
		 ambient_Color += vec3(0.6, 0.75, 1.0)	* 0.13	* TimeMidnight;

		 ambient_Color *= 1.0 - weatherRatio;
		 ambient_Color += vec3(0.75, 0.8, 1.0)			* TimeSunrise	* weatherRatio;
		 ambient_Color += vec3(0.75, 0.8, 1.0)			* TimeNoon		* weatherRatio;
		 ambient_Color += vec3(0.75, 0.8, 1.0)			* TimeSunset	* weatherRatio;
		 ambient_Color += vec3(0.6, 0.75, 1.0)	* 0.13 	* TimeMidnight	* weatherRatio;

	vec3 sunlight_Color  = vec3(0.0);
		 sunlight_Color += vec3(1.0, 0.7, 0.5)	* 0.6	* TimeSunrise;
		 sunlight_Color += vec3(1.0, 0.9, 0.8)			* TimeNoon;
		 sunlight_Color += vec3(1.0, 0.7, 0.5)	* 0.6	* TimeSunset;
		 sunlight_Color += vec3(0.6, 0.75, 1.0)	* 0.05	* TimeMidnight;
		 sunlight_Color *= DayToNightFading;
		 sunlight_Color *= 1.0 - weatherRatio;
		 
	vec3 torch_Color = vec3(1.0, 0.65, 0.4);

	float saturation = (1.0 - TimeMidnight * 0.5) + (torchLightmap * TimeMidnight * 0.5);
	float luma = dot(baseColor.rgb, vec3(1.0));
	vec3 chroma = baseColor.rgb - luma;
	vec3 noLight = (chroma * saturation) + luma;

	vec3 newTorchLightmap	= baseColor.rgb * torch_Color * torchLightmap;
	vec3 ambientLightmap	= noLight.rgb * ambient_Color * ambientStrength;
	vec3 sunlightLightmap	= noLight.rgb * sunlight_Color;

	ambientLightmap		   *= dynamicTonemapping(0.75, true, true, true);
	sunlightLightmap	   *= dynamicTonemapping(0.75, true, true, true);

	vec3 newLightmap		= skyLightmap + newTorchLightmap;

/* DRAWBUFFERS:01 */

	gl_FragData[0] = vec4(newLightmap, baseColor.a);

}
