#version 120

// Включения эффектов
#define	clouds
#define crepuscularRays
#define useDynamicTonemapping

varying vec4 texcoord;
varying vec3 lightVector;
varying float weatherRatio;

// Текстуры
uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D gaux2;
uniform sampler2D gnormal;

// Матрицы преобразований
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

// Позиции
uniform vec3 cameraPosition;
uniform vec3 sunPosition;

uniform ivec2 eyeBrightnessSmooth;

// переменные рендеринга
uniform float near;
uniform float far;
uniform float frameTimeCounter;
uniform float rainStrength;

uniform int worldTime;

uniform vec3 skyColor;

// коффы для суток
float time = worldTime;
float TimeSunrise = ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(time, 0.0, 3000.0) / 3000.0));
float TimeNoon = ((clamp(time, 0.0, 3000.0)) / 3000.0) - ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0);
float TimeSunset = ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0);
float TimeDay = TimeSunrise + TimeNoon + TimeSunset;
float DayToNightFading = 1.0 - (clamp((time - 12000.0) / 300.0, 0.0, 1.0) - clamp((time - 13000.0) / 300.0, 0.0, 1.0) + clamp((time - 22800.0) / 200.0, 0.0, 1.0) - clamp((time - 23400.0) / 200.0, 0.0, 1.0));

vec3 normal = texture2D(gnormal, texcoord.xy).xyz * 2.0 - 1.0;
float getDepth0 = texture2D(depthtex0, texcoord.xy).x;
float getDepth1 = texture2D(depthtex1, texcoord.xy).x;
float comp = 1.0 - near / far / far;

bool isWater = (length(normal) > 0.94 && length(normal) < 0.96);
bool land = getDepth0 < comp;
bool land2 = getDepth1 < comp;
bool sky = getDepth0 > comp;

// SSS
float subSurfaceScattering(vec3 vec, vec3 pos, float N)
{
	return pow(max(dot(vec, normalize(pos)), 0.0), N) * (N + 1.0) / 6.28;
}

// SSS stage 2
float subSurfaceScattering2(vec3 vec, vec3 pos, float N)
{
	return pow(max(dot(vec, normalize(pos)) * 0.5 + 0.5, 0.0), N) * (N + 1.0) / 6.28;
}

// шум для облаков
float getCloudNoise(vec3 fragpos, int integer_i)
{

	float cloudWindSpeed = 0.09;
	float cloudCover = 0.7;

	float noise = 0.0;

	#ifdef clouds

		vec2 wind[4] = vec2[4](vec2(abs(frameTimeCounter / 1000. - 0.5), abs(frameTimeCounter / 1000. - 0.5)) + vec2(0.5),
													vec2(-abs(frameTimeCounter / 1000. - 0.5), abs(frameTimeCounter / 1000. - 0.5)),
													vec2(-abs(frameTimeCounter / 1000. - 0.5), -abs(frameTimeCounter / 1000. - 0.5)),
													vec2(abs(frameTimeCounter / 1000. - 0.5), -abs(frameTimeCounter / 1000. - 0.5)));

		vec3 tpos = vec3(gbufferModelViewInverse * vec4(fragpos.xyz, 1.0));
		vec3 wVector = normalize(tpos);
		vec3 intersection = wVector * ((-300.0) / (wVector.y));

		float curvedCloudsPlane = pow(0.89, distance(vec2(0.0), intersection.xz) / 100);

		intersection = wVector * ((-cameraPosition.y + 500.0 - integer_i * 3. * (1.0 + curvedCloudsPlane * curvedCloudsPlane * 2.0) + 300 * sqrt(curvedCloudsPlane)) / (wVector.y));
		vec2 getCoord = (intersection.xz + cameraPosition.xz) / 1000.0 / 180. + wind[0] * cloudWindSpeed;
		vec2 coord = fract(getCoord / 2.0);

		noise += texture2D(noisetex, coord - wind[0] * cloudWindSpeed).x;
		noise += texture2D(noisetex, coord * 3.5 - wind[0] * cloudWindSpeed).x / 3.5;
		noise += texture2D(noisetex, coord * 12.25 - wind[0] * cloudWindSpeed).x / 12.25;
		noise += texture2D(noisetex, coord * 42.87 - wind[0] * cloudWindSpeed).x / 42.87;

	#endif

		cloudCover = mix(cloudCover, 0.1, weatherRatio);

		return max(noise - cloudCover, 0.0);
}

// маска для слоя неба
float getSkyMask(float cloudMask, vec2 lPos)
{

	float gr = 0.0;
	float depth = texture2D(depthtex0, texcoord.xy).x;

#ifdef crepuscularRays
	gr = mix(float(depth > comp), 0.0, cloudMask);
#else
	gr = float(depth > comp);
#endif

	if (texcoord.x < 0.002 && texcoord.y < 0.002)
	{

		for (int i = -6; i < 7; i++)
		{
			for (int j = -6; j < 7; j++)
			{

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

// отрисовка солнца
vec3 drawSun(vec3 clr, vec3 fragpos, vec2 lPos, vec3 sunClr, float waterSkyL, bool forReflections)
{

	float sunVector = max(dot(normalize(fragpos), lightVector), 0.0);

	float sun = clamp(pow(sunVector, 2000.0) * 3.0, 0.0, 1.0);

	if (forReflections)
		sun *= pow(waterSkyL, 20.0);

	return mix(clr, sunClr, sun * DayToNightFading * (1.0 - rainStrength) * max(1.0 - getCloudNoise(fragpos.xyz, 0) * 2.0, 0.0));
}

// отрисовка -неба
vec3 drawSky(vec3 worldPos, vec3 fragpos, vec3 skyClr, vec3 horizonClr, float waterSkyL, bool forReflections)
{
	float skyStrength = 1.0;
	float horizonStrength = 0.7;

	float position = abs(worldPos.y);

	float horizonPos = max(1.0 - pow(position / 200.0, 1.0), 0.0);
	float skyPos = max(position / 600.0, 0.0);

	float curvedStarsPlane = pow(0.89, distance(vec2(0.0), worldPos.xz) / 100.0);
	vec2 starsCoord = worldPos.xz / worldPos.y / 20.0 * (1.0 + curvedStarsPlane * curvedStarsPlane * 3.5) + vec2(frameTimeCounter / 800.0);

	vec3 skyColor = mix(skyClr, horizonClr, horizonPos);

	return skyColor;
}

// отрисовка облаков
vec3 draw2DClouds(vec3 clr, vec3 worldPos, vec3 fragpos, vec3 sunClr, vec3 cloudClr, float waterSkyL, bool forReflections)
{

	float cloudThickness = 1.0;
	float cloudSrfcScattering = 2.0;
	float overexposureFix = 0.15;

	#ifdef clouds

		vec3 tpos = vec3(gbufferModelViewInverse * vec4(fragpos.xyz, 1.0));
		vec3 wVector = normalize(tpos);

		vec4 totalcloud = vec4(0.0);

		vec3 intersection = wVector * ((-300.0) / (wVector.y));
		float curvedCloudsPlane = pow(0.89, distance(vec2(0.0), intersection.xz) / 100);

		cloudSrfcScattering = mix(cloudSrfcScattering, cloudSrfcScattering / 2.0, weatherRatio * TimeMidnight);

		for (int i = 0; i < 16; i++)
		{

			float cl = getCloudNoise(fragpos, i);
			float density = max(1.0 - cl * cloudThickness, 0.) * max(1.0 - cl * cloudThickness, 0.) * (i / 16.) * (i / 16.);

			vec3 c = cloudClr * overexposureFix;
			c = mix(c, sunClr * cloudSrfcScattering, subSurfaceScattering(lightVector, fragpos.xyz, 10.0) * pow(density, 3.0));
			c = mix(c, sunClr * 6.0 * cloudSrfcScattering, subSurfaceScattering2(lightVector, fragpos.xyz, 0.1) * pow(density, 2.0));

			cl = max(cl - (abs(i - 8.0) / 8.) * 0.2, 0.) * 0.08;

			totalcloud += vec4(c.rgb * exp(-totalcloud.a), cl);
			totalcloud.a = min(totalcloud.a, 1.0);
		}

		if (!forReflections)
		{
			float remove = clamp(worldPos.y + length(worldPos.y), 0.0, 1.0);
			totalcloud.a *= remove;
		}
		else
		{
			totalcloud.a *= pow(waterSkyL, 20.0);
		}

		clr.rgb = mix(clr.rgb, totalcloud.rgb, totalcloud.a * pow(curvedCloudsPlane, 1.2));

	#endif

		return clr;
}


void main()
{

	// исходный цвет
	vec3 color = texture2D(gcolor, texcoord.st).rgb;

	// преобразование координат для фиксирования под камеру перса
	vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * getDepth0 - 1.0f, 1.0f);
	fragposition /= fragposition.w;

	vec4 skyFragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f - 1.0f, 1.0f);
	skyFragposition /= skyFragposition.w;

	// кастом цвета солнца в зависимости от времени суток
	vec4 skyWorldPos = gbufferModelViewInverse * skyFragposition / far * 128.0; // Without depth.

	// расчет позиции солнца 
	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 pos1 = tpos.xy / tpos.z;
	vec2 lightPos = pos1 * 0.5 + 0.5;

	vec3 sun_Color = vec3(0.0);

	// кастом цвета солнца в зависимости от времени суток
	sun_Color += vec3(1.0, 0.8, 0.6) * 1.6 * TimeSunrise;
	sun_Color += vec3(1.0, 1.0, 1.0) * 1.6 * TimeNoon;
	sun_Color += vec3(1.0, 0.8, 0.6) * 1.6 * TimeSunset;
	sun_Color += vec3(0.85, 0.9, 1.0) * TimeMidnight;
	sun_Color *= DayToNightFading;

	vec3 sky_Color = vec3(0.0);

	// кастом цвета неба в зависимости от времени суток
	sky_Color += vec3(0.7, 0.8, 1.0) * TimeSunrise;
	sky_Color += vec3(0.55, 0.7, 1.0) * TimeNoon;
	sky_Color += vec3(0.7, 0.8, 1.0) * TimeSunset;
	sky_Color += vec3(0.6, 0.75, 1.0) * 0.1 * TimeMidnight;

	vec3 horizon_Color = vec3(0.0);

	// кастом цвета горизонта в зависимости от времени суток
	horizon_Color += vec3(1.0, 0.85, 0.7) * TimeSunrise;
	horizon_Color += vec3(1.0, 1.0, 1.0) * TimeNoon;
	horizon_Color += vec3(1.0, 0.85, 0.7) * TimeSunset;
	horizon_Color += vec3(0.6, 0.75, 1.0) * 0.2 * TimeMidnight;

	// отрисовка
	if (!land2)
 		color.rgb = drawSky(skyWorldPos.xyz, skyFragposition.xyz, sky_Color, horizon_Color, 0.0, false);
 	if (!land2)
 		color.rgb = drawSun(color.rgb, skyFragposition.xyz, lightPos, sun_Color, 0.0, false);
	if (!land2)
		color.rgb = draw2DClouds(color.rgb, skyWorldPos.xyz, skyFragposition.xyz, vec3(1., 1., 1.), vec3(1., 1., 0.), 0.0, false);

	/* DRAWBUFFERS:4 */

	// передаём данные в фргментData
	gl_FragData[0] = vec4(
		color,
		pow(
			getSkyMask(
				getCloudNoise(skyFragposition.xyz, 0),
				lightPos),
				3.0
			)
	);
}
