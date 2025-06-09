#version 120

//#define		enableDynamicWeather
float	weatherRatioSpeed		= 0.01;

varying vec4 texcoord;
varying vec3 lightVector;
varying float weatherRatio;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform int worldTime;

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

void main() {
	
	texcoord = gl_MultiTexCoord0;
	
	gl_Position = ftransform();
	
	if (worldTime < 12700 || worldTime > 23250) {
		lightVector = normalize(sunPosition);
	} else {
		lightVector = normalize(moonPosition);
	}
	
	#ifdef enableDynamicWeather
		weatherRatio = dynamicWeather(weatherRatioSpeed);
	#else
		weatherRatio = rainStrength;
	#endif
	
}
