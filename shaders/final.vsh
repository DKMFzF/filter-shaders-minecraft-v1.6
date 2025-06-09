#version 120

#define enableDynamicWeather
float weatherRatioSpeed = 0.01;

varying vec4 texcoord;
varying vec3 lightVector;
varying float weatherRatio;

uniform vec3 sunPosition;
uniform vec3 moonPosition;

uniform float rainStrength;
uniform float frameTimeCounter;

uniform int worldTime;

float dynamicWeather(float speed)
{

	float value = 1.0;
	value *= abs(sin(frameTimeCounter * speed * 1.2));
	value *= abs(cos(frameTimeCounter * speed * 0.5));
	value *= abs(sin(frameTimeCounter * speed * 2.0));

	value = mix(value, 1.0, rainStrength);

	return value;
}

void main()
{

	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

	if (worldTime < 12700 || worldTime > 23250)
	{
		lightVector = normalize(sunPosition);
	}
	else
	{
		lightVector = normalize(moonPosition);
	}

#ifdef enableDynamicWeather
	weatherRatio = dynamicWeather(weatherRatioSpeed);
#else
	weatherRatio = rainStrength;
#endif
}
