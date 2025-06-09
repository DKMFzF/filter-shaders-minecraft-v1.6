#version 120

//#define	clouds
//#define	waterRefraction
//#define	screenSpaceReflections
//#define volumetricFog				// Obviously, when enabled, there is more fog because only then the rays become visible.
//#define crepuscularRays			// The lens flare might twitch, so better turn it off then. Clouds needs to be enabled!
#define	useDynamicTonemapping

varying vec4 texcoord;
varying vec3 lightVector;
varying float weatherRatio;

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gnormal;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 upPosition;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform float near;
uniform float far;
uniform float frameTimeCounter;
uniform float centerDepthSmooth;
uniform float aspectRatio;
uniform float rainStrength;

uniform int isEyeInWater;
uniform int worldTime;

// Calculate Time of Day.
float time = worldTime;
float TimeSunrise		= ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(time, 0.0, 3000.0)/3000.0));
float TimeNoon			= ((clamp(time, 0.0, 3000.0)) / 3000.0) - ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0);
float TimeSunset		= ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight		= ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0);
float TimeDay			= TimeSunrise + TimeNoon + TimeSunset;
float DayToNightFading	= 1.0 - (clamp((time - 12000.0) / 300.0, 0.0, 1.0) - clamp((time - 13000.0) / 300.0, 0.0, 1.0)
							  +  clamp((time - 22800.0) / 200.0, 0.0, 1.0) - clamp((time - 23400.0) / 200.0, 0.0, 1.0));

vec3	normal			= texture2D(gnormal, texcoord.xy).xyz * 2.0 - 1.0;
float	getDepth0		= texture2D(depthtex0, texcoord.xy).x;
float	getDepth1		= texture2D(depthtex1, texcoord.xy).x;
float	comp			= 1.0 - near / far / far;

bool	isWater			= (length(normal) > 0.94 && length(normal) < 0.96);
bool	land			= getDepth0 < comp;
bool	land2			= getDepth1 < comp;
bool	sky				= getDepth0 > comp;

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}

float linearDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float subSurfaceScattering(vec3 vec,vec3 pos, float N) {
	return pow(max(dot(vec, normalize(pos)), 0.0), N) * (N + 1.0) / 6.28;
}

float subSurfaceScattering2(vec3 vec,vec3 pos, float N) {
	return pow(max(dot(vec, normalize(pos)) * 0.5 + 0.5, 0.0), N) * (N + 1.0)/ 6.28;
}

float dynamicTonemapping(float exposureStrength, bool reserveLightmap, bool addExposure, bool dayOnly) {

	float dTonemap = 1.0;

	#ifdef useDynamicTonemapping
	
		float dTlightmap	= pow(eyeBrightnessSmooth.y / 240.0, 2.0);		if (reserveLightmap)	dTlightmap 	= 1.0 - dTlightmap;
			  dTonemap		= dTlightmap * exposureStrength;				if (addExposure)		dTonemap	= 1.0 + dTonemap;		if (dayOnly)	dTonemap = mix(dTonemap, 1.0, TimeMidnight);	// Full exposure on midnight.

	#endif
	
	return dTonemap;

}

float vec3ToFloat(vec3 vec3Input) {

	float floatValue  = 0.0;
		  floatValue += vec3Input.x;
		  floatValue += vec3Input.y;
		  floatValue += vec3Input.z;

		  floatValue /= 3.0;

	return floatValue;

}

float getCloudNoise(vec3 fragpos, int integer_i) {

	float cloudWindSpeed 	= 0.09;
	float cloudCover 		= 0.7;
	
	float noise = 0.0;
	
	#ifdef clouds

		vec2 wind[4] = vec2[4](vec2(abs(frameTimeCounter/1000.-0.5), abs(frameTimeCounter/1000.-0.5))+vec2(0.5),
							   vec2(-abs(frameTimeCounter/1000.-0.5), abs(frameTimeCounter/1000.-0.5)),
							   vec2(-abs(frameTimeCounter/1000.-0.5), -abs(frameTimeCounter/1000.-0.5)),
							   vec2(abs(frameTimeCounter/1000.-0.5), -abs(frameTimeCounter/1000.-0.5)));

		vec3 tpos			= vec3(gbufferModelViewInverse * vec4(fragpos.xyz, 1.0));
		vec3 wVector		= normalize(tpos);
		vec3 intersection	= wVector * ((-300.0) / (wVector.y));

		float curvedCloudsPlane = pow(0.89, distance(vec2(0.0), intersection.xz) / 100);

		intersection = wVector * ((-cameraPosition.y + 500.0 - integer_i * 3. * (1.0 + curvedCloudsPlane * curvedCloudsPlane * 2.0) + 300 * sqrt(curvedCloudsPlane)) / (wVector.y));
		vec2 getCoord = (intersection.xz + cameraPosition.xz) / 1000.0 / 180. + wind[0] * cloudWindSpeed;
		vec2 coord = fract(getCoord / 2.0);

		noise += texture2D(noisetex, coord			- wind[0] * cloudWindSpeed).x;
		noise += texture2D(noisetex, coord * 3.5	- wind[0] * cloudWindSpeed).x / 3.5;
		noise += texture2D(noisetex, coord * 12.25	- wind[0] * cloudWindSpeed).x / 12.25;
		noise += texture2D(noisetex, coord * 42.87	- wind[0] * cloudWindSpeed).x / 42.87;
		  
	#endif
	
	cloudCover = mix(cloudCover, 0.1, weatherRatio);

	return max(noise - cloudCover, 0.0);

}

float getSkyMask(float cloudMask, vec2 lPos) {

	float gr	= 0.0;
	float depth	= texture2D(depthtex0, texcoord.xy).x;

	#ifdef crepuscularRays
		gr = mix(float(depth > comp), 0.0, cloudMask);
	#else
		gr = float(depth > comp);
	#endif

	// Calculate sun occlusion (only on one pixel).
	if (texcoord.x < 0.002 && texcoord.y < 0.002) {

		for (int i = -6; i < 7;i++) {
			for (int j = -6; j < 7 ;j++) {

				vec2 ij = vec2(i, j);
				float temp = texture2D(depthtex0, lPos + sign(ij) * sqrt(abs(ij)) * vec2(0.002)).x;

				#ifdef crepuscularRays
					gr += mix(float(temp > comp), 0.0, cloudMask);
				#else
					gr += float(temp > comp);
				#endif

			}
		}

		gr /= 144.0;

	}

	return gr;

}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec3 drawSun(vec3 clr, vec3 fragpos, vec2 lPos, vec3 sunClr, float waterSkyL, bool forReflections) {

	// Get position.
	float sunVector = max(dot(normalize(fragpos), lightVector), 0.0);

	// Calculate sun.
	float sun = clamp(pow(sunVector, 2000.0) * 3.0, 0.0, 1.0);

	// Desaturate sun color at daytime.
	//sunClr = mix(sunClr, pow(sunClr, vec3(0.25)), TimeDay);

	if (forReflections) sun *= pow(waterSkyL, 20.0);
	

	return mix(clr, sunClr, sun * DayToNightFading * (1.0 - rainStrength) * max(1.0 - getCloudNoise(fragpos.xyz, 0) * 2.0, 0.0));

}

vec3 drawSky(vec3 worldPos, vec3 fragpos, vec3 skyClr, vec3 horizonClr, float waterSkyL, bool forReflections) {
    float skyStrength = 1.0;
    float horizonStrength = 0.7;

    // Get position.
    float position = abs(worldPos.y);

    float horizonPos = max(1.0 - pow(position / 200.0, 1.0), 0.0);
    float skyPos = max(position / 600.0, 0.0);

    // Draw stars (если нужно).
    float curvedStarsPlane = pow(0.89, distance(vec2(0.0), worldPos.xz) / 100.0);
    vec2 starsCoord = worldPos.xz / worldPos.y / 20.0 * (1.0 + curvedStarsPlane * curvedStarsPlane * 3.5) + vec2(frameTimeCounter / 800.0);

    vec3 skyColor = mix(skyClr, horizonClr, horizonPos);

    // Возвращаем цвет неба, но не перезаписываем полностью (если нужно оставить облака)
    return skyColor;
}

vec3 draw2DClouds(vec3 clr, vec3 worldPos, vec3 fragpos, vec3 sunClr, vec3 cloudClr, float waterSkyL, bool forReflections) {

	float	cloudThickness		= 1.0;
	float	cloudSrfcScattering	= 2.0;
	float	overexposureFix		= 0.15;

	// Draw clouds.
	#ifdef clouds

		// Code by Chocapic13.

		vec3 tpos = vec3(gbufferModelViewInverse * vec4(fragpos.xyz, 1.0));
		vec3 wVector = normalize(tpos);

		vec4 totalcloud = vec4(0.0);

		vec3 intersection = wVector * ((-300.0) / (wVector.y));
		float curvedCloudsPlane = pow(0.89, distance(vec2(0.0), intersection.xz) / 100);

		// Modifiy variables on different conditions.
		cloudSrfcScattering = mix(cloudSrfcScattering,	cloudSrfcScattering / 2.0,	weatherRatio * TimeMidnight);

		for (int i = 0; i < 16; i++) {

			float cl = getCloudNoise(fragpos, i);
			float density = max(1.0 - cl * cloudThickness, 0.) * max(1.0 - cl * cloudThickness, 0.) * (i / 16.) * (i /16.);

			vec3 c = cloudClr * overexposureFix;
				 c = mix(c, sunClr *		cloudSrfcScattering, subSurfaceScattering(lightVector, fragpos.xyz, 10.0) * pow(density, 3.0));
				 c = mix(c, sunClr * 6.0 *	cloudSrfcScattering, subSurfaceScattering2(lightVector, fragpos.xyz, 0.1) * pow(density, 2.0));

			cl = max(cl - (abs(i - 8.0) / 8.) * 0.2, 0.) * 0.08;

			totalcloud += vec4(c.rgb * exp(-totalcloud.a), cl);
			totalcloud.a = min(totalcloud.a, 1.0);

		}

		if (!forReflections) {

			// Remove clouds under the horizon line.
			float remove = clamp(worldPos.y + length(worldPos.y), 0.0, 1.0);
			totalcloud.a *= remove;

		} else {
		
			totalcloud.a *= pow(waterSkyL, 20.0);
		
		}

		clr.rgb = mix(clr.rgb, totalcloud.rgb, totalcloud.a * pow(curvedCloudsPlane, 1.2));

	#endif

	return clr;

}

vec3 calcFog(vec3 clr, vec3 fogClr, vec3 worldPos, vec3 fragpos) {
	
	#ifdef volumetricFog

		float fogStartDistance		= 50.0;	// Higher -> far.
		float fogDensity 			= 0.4;

		// Decrease fog distance at rain.
		fogStartDistance = mix(fogStartDistance, fogStartDistance / 1.5, rainStrength);
		
		// Apply dynamic tonemapping.
		fogClr *= dynamicTonemapping(1.0, true, true, true);

		float fogFactor = 1.0 - exp(-pow(length(fragpos.xyz) / max(fogStartDistance, 0.0), 2.0));
			  fogFactor = fogFactor * fogDensity;
			  
		// Remove fog when player is underwater.
		if (isEyeInWater > 0.9) fogFactor = 0.0;
			  
		// Volumetric Rays.
		float vlRays = texture2D(gdepth, texcoord.st).g;
			  vlRays = mix(vlRays * fogFactor, 1.0, pow(fogFactor, 2.0));
			  vlRays = mix(vlRays, fogFactor, rainStrength);

		clr = mix(clr.rgb, fogClr, vlRays);
		
	#else
	
		float fogStartDistance		= 100.0;	// Higher -> far.
		float fogDensity 			= 0.4;
		float ABFthickness  		= 75.0;	// ABF = Altitute based fog.

		// Calculate position.
		float position  = abs(worldPos.y + cameraPosition.y - 64.0);
		float ABFpos    = max(1.0 - pow(position / ABFthickness, 0.6), 0.0);

		// Decrease fog distance at rain.
		fogStartDistance = mix(fogStartDistance, fogStartDistance / 1.5, rainStrength);
		
		// Apply dynamic tonemapping.
		fogClr *= dynamicTonemapping(1.0, true, true, true);

		float fogFactor = 1.0 - exp(-pow(length(fragpos.xyz) / max(fogStartDistance, 0.0), 2.0));
			  fogFactor = mix(0.0, fogFactor * fogDensity, ABFpos);
			  
		// Fog should disappear in buildings/caves.
		fogFactor = mix(fogFactor, 0.0, 1.0 - (eyeBrightnessSmooth.y / 240.0));
		
		// Remove fog when player is underwater.
		if (isEyeInWater > 0.9) fogFactor = 0.0;

		clr = mix(clr.rgb, fogClr, fogFactor);
		
	#endif

	return clr;

}

vec3 calcUnderwaterFog(vec3 clr, vec3 fogClr, vec3 worldPos, vec3 fragpos) {

	float fogExposure 			= 1.0;
	float fogStartDistance		= 15.0;	// Higher -> far.
	float fogDensity 			= 1.0;
	
	float skyLightmap = texture2D(gdepth, texcoord.xy).r;

	float fogFactor = 1.0 - exp(-pow(length(fragpos.xyz) / fogStartDistance, 2.0));
		  fogFactor = mix(0.0, fogFactor * (1.0 - skyLightmap * (eyeBrightness.y / 240.0) * 0.5), fogDensity);
	
	//if (!land2) fogFactor = fogFactor * 0.9;

	clr = mix(clr.rgb, fogClr * fogExposure, fogFactor);

	return clr;

}

vec4 raytrace(vec3 fragpos, vec3 rVector, vec3 normal, vec3 worldPos, vec3 skyWorldPos, vec2 lPos, float waterSkyL, vec3 fogClr, vec3 skyClr, vec3 horizonClr, vec3 sunClr, vec3 cloudClr, vec3 cloudSunClr) {

	const int maxf = 4;				//number of refinements
	const float stp = 1.0;			//size of one step for raytracing algorithm
	const float ref = 0.1;			//refinement multiplier
	const float inc = 2.0;			//increasement factor at each step

	vec4 color = vec4(0.0);

	#ifdef screenSpaceReflections

		vec3 start = fragpos;
		vec3 vector = stp * rVector;

		fragpos += vector;
		vec3 tvector = vector;
		
		int sr = 0;

		for (int i = 0; i < 20; i++) {

			vec3 pos = nvec3(gbufferProjection * vec4(fragpos, 1.0)) * 0.5 + 0.5;
			if (pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1.0) break;

				vec3 spos = vec3(pos.st, texture2D(depthtex1, pos.st).r);
					 spos = nvec3(gbufferProjectionInverse * vec4(spos * 2.0 - 1.0, 1.0));

				float err = length(fragpos.xyz-spos.xyz);

				if (err < length(vector) * pow(length(tvector), 0.11) * 1.75) {

					sr++;

					if (sr >= maxf) {

						bool rLand = texture2D(depthtex1, pos.st).r < comp;

						float border = clamp(1.0 - pow(cdist(pos.st), 5.0), 0.0, 1.0);
						color = texture2D(gcolor, pos.st);

						if (land == true) color.rgb = calcFog(color.rgb, fogClr, worldPos, fragpos);	// Recalculate fog.

							if (rLand == false) {	// Fake sky reflections in empty spaces.

								color.rgb = drawSky(skyWorldPos, rVector, skyClr, horizonClr, waterSkyL, true);
								color.rgb = drawSun(color.rgb, fragpos, lPos, sunClr, waterSkyL, true);
								color.rgb = draw2DClouds(color.rgb, skyWorldPos, fragpos, cloudSunClr, cloudClr, waterSkyL, true);

							}

						color.a = 1.0;
						color.a *= border;

						break;

					}

				tvector -=vector;
				vector *=ref;

			}

			vector *= inc;
			tvector += vector;
			fragpos = start + tvector;

		}

	#endif

	return color;

}

float waterWaves(vec3 worldPos) {

	float waveSpeed = 0.75;

	vec2 coord = fract(vec2(worldPos.xz / 2000.0));

	float noise =  texture2D(noisetex, coord * 1.5 + vec2(frameTimeCounter / 1000.0 * waveSpeed)).x / 1.5;
		  noise += texture2D(noisetex, coord * 1.5 - vec2(frameTimeCounter / 1000.0 * waveSpeed)).x / 1.5;
		  noise += texture2D(noisetex, coord * 3.5 + vec2(frameTimeCounter / 600.0 * waveSpeed)).x / 3.5;
		  noise += texture2D(noisetex, coord * 3.5 - vec2(frameTimeCounter / 600.0 * waveSpeed)).x / 3.5;
		  noise += texture2D(noisetex, coord * 7.0 + vec2(frameTimeCounter / 300.0 * waveSpeed)).x / 7.0;
		  noise += texture2D(noisetex, coord * 7.0 - vec2(frameTimeCounter / 300.0 * waveSpeed)).x / 7.0;

	return noise;

}

vec3 drawAlphaColor(vec3 clr) {

	// For colored glass and ice.
	vec4 aColor = texture2D(gaux2, texcoord.xy);
	
	return mix(clr, aColor.rgb, aColor.a) + aColor.rgb * (1.0 - aColor.a);

}

void main() {

	// Get main color.
	vec3 color = texture2D(gcolor, texcoord.st).rgb;

	// Set up positions.
	vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * getDepth0 - 1.0f, 1.0f);
	fragposition /= fragposition.w;

	vec4 skyFragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f - 1.0f, 1.0f);
	skyFragposition /= skyFragposition.w;

	vec4 worldposition   = gbufferModelViewInverse * fragposition;
	vec4 skyWorldPos	 = gbufferModelViewInverse * skyFragposition / far * 128.0;		// Without depth.

	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 pos1 = tpos.xy / tpos.z;
	vec2 lightPos = pos1 * 0.5 + 0.5;

	// Set up colors.
	vec3 sun_Color  = vec3(0.0);
		 sun_Color += vec3(1.0, 0.8, 0.6) 	* 1.6	* TimeSunrise;
		 sun_Color += vec3(1.0, 1.0, 1.0) 	* 1.6	* TimeNoon;
		 sun_Color += vec3(1.0, 0.8, 0.6) 	* 1.6	* TimeSunset;
		 sun_Color += vec3(0.85, 0.9, 1.0)			* TimeMidnight;
		 sun_Color *= DayToNightFading;

	vec3 fog_Color  = vec3(0.0);
		 fog_Color += vec3(0.8, 0.85, 1.0)			* TimeSunrise;
		 fog_Color += vec3(0.8, 0.85, 1.0)			* TimeNoon;
		 fog_Color += vec3(0.8, 0.85, 1.0)			* TimeSunset;
		 fog_Color += vec3(0.6, 0.75, 1.0) * 0.2	* TimeMidnight;

		 fog_Color *= 1.0 - weatherRatio;
		 fog_Color += vec3(1.0, 1.0, 1.0)  			* TimeSunrise  * weatherRatio;
		 fog_Color += vec3(0.9, 0.95, 1.0) 			* TimeNoon     * weatherRatio;
		 fog_Color += vec3(1.0, 1.0, 1.0)  			* TimeSunset   * weatherRatio;
		 fog_Color += vec3(0.6, 0.75, 1.0) * 0.15 	* TimeMidnight * weatherRatio;

	vec3 sky_Color  = vec3(0.0);
		 sky_Color += vec3(0.7, 0.8, 1.0)			* TimeSunrise;
		 sky_Color += vec3(0.55, 0.7, 1.0)			* TimeNoon;
		 sky_Color += vec3(0.7, 0.8, 1.0)			* TimeSunset;
		 sky_Color += vec3(0.6, 0.75, 1.0) * 0.1 	* TimeMidnight;

		 sky_Color *= 1.0 - weatherRatio;
		 sky_Color += vec3(0.8, 0.87, 1.0) 			* TimeDay		* weatherRatio;
		 sky_Color += vec3(0.5, 0.75, 1.0) * 0.15	* TimeMidnight	* weatherRatio;

	vec3 horizon_Color  = vec3(0.0);
		 horizon_Color += vec3(1.0, 0.85, 0.7)			* TimeSunrise;
		 horizon_Color += vec3(1.0, 1.0, 1.0)			* TimeNoon;
		 horizon_Color += vec3(1.0, 0.85, 0.7)			* TimeSunset;
		 horizon_Color += vec3(0.6, 0.75, 1.0)	* 0.2	* TimeMidnight;

		 horizon_Color *= 1.0 - weatherRatio;
		 horizon_Color += vec3(1.0, 0.85, 0.75)			* TimeSunrise		* weatherRatio;
		 horizon_Color += vec3(1.0, 1.0, 1.0)			* TimeNoon			* weatherRatio;
		 horizon_Color += vec3(1.0, 0.85, 0.75)			* TimeSunset		* weatherRatio;
		 horizon_Color += vec3(0.6, 0.75, 1.0)	* 0.2	* TimeMidnight		* weatherRatio;

	vec3 cloud_Color  = vec3(0.0);
		 cloud_Color += vec3(1.0, 1.0, 1.0)		* 0.4	* TimeSunrise;
		 cloud_Color += vec3(1.0, 0.9, 0.8)		* 0.6	* TimeNoon;
		 cloud_Color += vec3(1.0, 1.0, 1.0)		* 0.4	* TimeSunset;
		 cloud_Color += vec3(0.7, 0.8, 1.0)		* 0.1	* TimeMidnight;

		 cloud_Color *= 1.0 - weatherRatio;
		 cloud_Color += vec3(1.0, 1.0, 1.0)		* 0.4	* TimeDay		* weatherRatio;
		 cloud_Color += vec3(0.6, 0.8, 1.0)		* 0.1	* TimeMidnight	* weatherRatio;
		 
	vec3 cloudSun_Color  = vec3(0.0);
		 cloudSun_Color += vec3(1.0, 0.7, 0.4)			* TimeSunrise;
		 cloudSun_Color += vec3(1.0, 0.85, 0.6) 		* TimeNoon;
		 cloudSun_Color += vec3(1.0, 0.7, 0.4)			* TimeSunset;
		 cloudSun_Color += vec3(0.6, 0.7, 1.0)	* 0.5	* TimeMidnight;
		 cloudSun_Color *= DayToNightFading;
		 
	vec3 water_Color = vec3(0.8, 0.9, 1.0);
	
	vec3 underwater_Color  = vec3(0.0);
		 underwater_Color += vec3(0.1, 0.6, 1.0)			* TimeDay;
		 underwater_Color += vec3(0.1, 0.6, 1.0)	* 0.2	* TimeMidnight;

	if (isWater) {	// Water
	
		float exposureFix = 0.33;	// Should have the same value like in gbuffers_water.fsh -> watercolor.a;

		vec2 waterTexcoord = texcoord.st;

		#ifdef waterRefraction

			// By Chocapic13.

			float	waterRefractionStrength = 0.01;

			float deltaPos = 0.1;
			float h0 = waterWaves(worldposition.xyz + cameraPosition.xyz);
			float h1 = waterWaves(worldposition.xyz + cameraPosition.xyz - vec3(deltaPos, 0.0, 0.0));
			float h2 = waterWaves(worldposition.xyz + cameraPosition.xyz - vec3(0.0, 0.0, deltaPos));

			float dX = ((h0-h1))/deltaPos;
			float dY = ((h0-h2))/deltaPos;

			vec3 refract = normalize(vec3(dX,dY,1.0));
			float refMult = sqrt(1.0-dot(normal,normalize(fragposition).xyz)*dot(normal,normalize(fragposition).xyz)) * waterRefractionStrength * (1.0 - linearDepth(getDepth0) * 2.0);

			waterTexcoord = texcoord.xy + refract.xy*refMult;
			vec3 mask = texture2D(gnormal, waterTexcoord.st).xyz*2.0-1.0;
			bool watermask = length(mask) > 0.94 && length(mask) < 0.98;
			waterTexcoord.st = watermask? waterTexcoord.st : texcoord.st;

		#endif
		
		float skyLightmap		= texture2D(gdepth, waterTexcoord.xy).r;
		float waterSkyLightmap	= texture2D(gaux3, waterTexcoord.xy).r;
		
		float waterDepth = mix(1.0 - skyLightmap, 0.0, 1.0 - waterSkyLightmap);

		// Get main color.
		vec3 watercolor = texture2D(gcolor, waterTexcoord.st).rgb;
		
		color.rgb = mix(watercolor * water_Color, underwater_Color * 0.25, waterDepth * 0.75);

		vec3 reflectedVector = reflect(normalize(fragposition.xyz), normal);		// Overwrites fragposition and flips the image.
		vec3 relfectedSky = drawSky(skyWorldPos.xyz, reflectedVector.xyz, sky_Color, horizon_Color, waterSkyLightmap, true);

		float normalDotEye = dot(normal, normalize(fragposition.xyz));
		float fresnel = pow(1.0 + normalDotEye, 2.0);

		vec4 reflection = raytrace(fragposition.xyz, reflectedVector, normal, worldposition.xyz, skyWorldPos.xyz, lightPos, waterSkyLightmap, fog_Color, sky_Color, horizon_Color, sun_Color, cloud_Color, cloudSun_Color);
			 reflection.rgb = mix(relfectedSky, reflection.rgb, reflection.a);

		color.rgb = drawSun(color.rgb, reflectedVector.xyz, lightPos, sun_Color, waterSkyLightmap, true);
		color.rgb = mix(color.rgb, draw2DClouds(color.rgb, skyWorldPos.xyz, reflectedVector.xyz * 10.0, cloudSun_Color, cloud_Color, waterSkyLightmap, true), sqrt(fresnel));
		color.rgb = mix(color.rgb, reflection.rgb, fresnel);
		
		// Exposure fix.
		color.rgb += color.rgb * exposureFix;

	}

	if (!land2) color.rgb = drawSky(skyWorldPos.xyz, skyFragposition.xyz, sky_Color, horizon_Color, 0.0, false);
	if (!land2) color.rgb = drawSun(color.rgb, skyFragposition.xyz, lightPos, sun_Color, 0.0, false);
	if (!land2) color.rgb = draw2DClouds(color.rgb, skyWorldPos.xyz, skyFragposition.xyz, cloudSun_Color, cloud_Color, 0.0, false);
	if (!land2) color.rgb = color.rgb * dynamicTonemapping(0.5, true, true, false);

	color = drawAlphaColor(color);
	
	if (isEyeInWater > 0.9) {

		color.rgb = calcUnderwaterFog(color.rgb * water_Color, underwater_Color * 0.25, worldposition.xyz, fragposition.xyz);
	
	}
	
	if (land2) color.rgb = calcFog(color.rgb, fog_Color, worldposition.xyz, fragposition.xyz);


/* DRAWBUFFERS:4 */

	gl_FragData[0] = vec4(color, pow(getSkyMask(getCloudNoise(skyFragposition.xyz, 0), lightPos), 3.0));

}
