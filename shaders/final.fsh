#version 120

#define useDynamicTonemapping
#define tonemapping
#define chromaticAberration

uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gaux1;
uniform sampler2D gaux4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;

uniform vec3 sunPosition;

varying vec4 texcoord;
varying vec3 lightVector;
varying float weatherRatio;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float aspectRatio;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float centerDepthSmooth;
uniform float frameTimeCounter;
uniform float rainStrength;

uniform int isEyeInWater;
uniform int worldTime;

float time = worldTime;
float TimeSunrise = ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(time, 0.0, 3000.0) / 3000.0));
float TimeNoon = ((clamp(time, 0.0, 3000.0)) / 3000.0) - ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0);
float TimeSunset = ((clamp(time, 9000.0, 12000.0) - 9000.0) / 3000.0) - ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(time, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(time, 23000.0, 24000.0) - 23000.0) / 1000.0);
float TimeDay = TimeSunrise + TimeNoon + TimeSunset;
float DayToNightFading = 1.0 - (clamp((time - 12000.0) / 300.0, 0.0, 1.0) - clamp((time - 13000.0) / 300.0, 0.0, 1.0) + clamp((time - 22800.0) / 200.0, 0.0, 1.0) - clamp((time - 23400.0) / 200.0, 0.0, 1.0));

float getDepth = texture2D(depthtex0, texcoord.xy).x;
vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);

float linearDepth(float depth)
{
	return (2.0 * near) / (far + near - depth * (far - near));
}

float vec3ToFloat(vec3 vec3Input)
{

	float floatValue = 0.0;
	floatValue += vec3Input.x;
	floatValue += vec3Input.y;
	floatValue += vec3Input.z;

	floatValue /= 3.0;

	return floatValue;
}

const vec2 coordsOffsets28[28] = vec2[28](vec2(1.0, 0.0),
																					vec2(0.0, 1.0),

																					vec2(-1.0, 0.0),
																					vec2(0.0, -1.0),

																					vec2(0.5, 0.0),
																					vec2(0.0, 0.5),

																					vec2(-0.5, 0.0),
																					vec2(0.0, -0.5),

																					vec2(0.25, 0.0),
																					vec2(0.0, 0.25),

																					vec2(-0.25, 0.0),
																					vec2(0.0, -0.25),

																					vec2(1.0, 0.5),
																					vec2(0.5, 1.0),

																					vec2(-1.0, 0.5),
																					vec2(0.5, -1.0),

																					vec2(-0.5, 1.0),
																					vec2(1.0, -0.5),

																					vec2(-1.0, -0.5),
																					vec2(-0.5, -1.0),

																					vec2(0.5, 0.25),
																					vec2(0.25, 0.5),

																					vec2(-0.5, 0.25),
																					vec2(0.25, -0.5),

																					vec2(-0.25, 0.5),
																					vec2(0.5, -0.25),

																					vec2(-0.25, -0.5),
																					vec2(-0.5, -0.25));

float dynamicTonemapping(float exposureStrength, bool reserveLightmap, bool addExposure, bool dayOnly)
{

	float dTonemap = 1.0;

#ifdef useDynamicTonemapping

	float dTlightmap = pow(eyeBrightnessSmooth.y / 240.0, 2.0);
	if (reserveLightmap)
		dTlightmap = 1.0 - dTlightmap;
	dTonemap = dTlightmap * exposureStrength;
	if (addExposure)
		dTonemap = 1.0 + dTonemap;
	if (dayOnly)
		dTonemap = mix(dTonemap, 1.0, TimeMidnight); // Full exposure on midnight.

#endif

	return dTonemap;
}

float getTruePos()
{

	float truePos = 0.0f;

	if ((worldTime < 13000 || worldTime > 23000) && sunPosition.z < 0)
		truePos = 1.0 * TimeDay;
	if ((worldTime < 23000 || worldTime > 13000) && -sunPosition.z < 0)
		truePos = 1.0 * TimeMidnight;

	return truePos;
}

float distratio(vec2 pos, vec2 pos2, float ratio)
{

	float xvect = pos.x * ratio - pos2.x * ratio;
	float yvect = pos.y - pos2.y;
	return sqrt(xvect * xvect + yvect * yvect);
}

float yDistAxis(in float degrees)
{

	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 lightPos = tpos.xy / tpos.z;
	lightPos = (lightPos + 1.0f) / 2.0f;

	return abs((lightPos.y - lightPos.x * (degrees)) - (texcoord.y - texcoord.x * (degrees)));
}

float smoothCircleDist(in float lensDist)
{

	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 lightPos = tpos.xy / tpos.z * lensDist;
	lightPos = (lightPos + 1.0f) / 2.0f;

	return distratio(lightPos.xy, texcoord.xy, aspectRatio);
}

float cirlceDist(float lensDist, float size)
{

	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 lightPos = tpos.xy / tpos.z * lensDist;
	lightPos = (lightPos + 1.0f) / 2.0f;

	return pow(min(distratio(lightPos.xy, texcoord.xy, aspectRatio), size) / size, 10.0);
}

vec2 underwaterRefraction(vec2 coord)
{

	float refractionMultiplier = 0.003;
	float refractionSpeed = 5.0;

	vec2 refractCoord = vec2(0.0);

	if (isEyeInWater > 0.9)
	{

		refractCoord = vec2(sin(frameTimeCounter * refractionSpeed + coord.x * 25.0 + coord.y * 12.0),
												cos(frameTimeCounter * refractionSpeed * 0.5 + coord.y * 12.0 + coord.x * 25.0));
	}

	return coord + refractCoord * refractionMultiplier;
}

vec3 drawRainDrops(vec3 clr, vec2 coord)
{

	float rainTransparency = 0.2;

	float rainTexture = vec3ToFloat(texture2D(gaux4, coord.st).rgb);

	rainTransparency = mix(rainTransparency, rainTransparency / 4.0, TimeMidnight);

	return mix(clr, vec3(1.0), rainTexture * rainTransparency);
}

vec3 doTonemapping(vec3 clr)
{

	float gamma = 1.0;
	float exposure = 1.1;
	float darkness = 0.03;
	float brightness = 0.03;
	float saturation = 1.07;

#ifdef tonemapping

	clr = pow(clr, vec3(gamma));
	clr *= exposure;
	clr = max(clr - darkness, 0.0);
	clr = clr + brightness;

	float luma = dot(clr, vec3(1.0));
	vec3 chroma = clr - luma;
	clr = (chroma * saturation) + luma;

#endif

	return clr;
}

vec3 doVignette(vec3 clr)
{

	float vignetteStrength = 3.0;
	float vignetteSharpness = 5.0;

	float dist = 1.0 - pow(distance(texcoord.st, vec2(0.5)), vignetteSharpness) * vignetteStrength * dynamicTonemapping(1.0, false, false, false);

	clr *= dist;

	return clr;
}

vec3 doCinematicMode(vec3 clr)
{

#ifdef cinematicMode

	if (texcoord.t > 0.9 || texcoord.t < 0.1)
		clr.rgb = vec3(0.0);

#endif

	return clr;
}

vec3 doCameraNoise(vec3 clr)
{

	float noiseStrength = 0.025;
	float noiseResoltion = 0.2;

#ifdef cameraNoise

	vec2 aspectcorrect = vec2(aspectRatio, 1.0);

	vec3 rgbNoise = texture2D(noisetex, texcoord.st * noiseResoltion * aspectcorrect + vec2(frameTimeCounter)).rgb;

	clr = mix(clr, rgbNoise, vec3ToFloat(rgbNoise) * noiseStrength);

#endif

	return clr;
}

vec3 doChromaticAberration(vec3 clr, vec2 coord)
{

	float offsetMultiplier = 0.01;

#ifdef chromaticAberration

	float dist = pow(distance(coord.st, vec2(0.5)), 3.0);

	float rChannel = texture2D(gaux1, coord.st + vec2(offsetMultiplier * dist, 0.0)).r;
	float gChannel = texture2D(gaux1, coord.st).g;
	float bChannel = texture2D(gaux1, coord.st - vec2(offsetMultiplier * dist, 0.0)).b;

	clr = vec3(rChannel, gChannel, bChannel);

#endif

	return clr;
}

vec3 renderDOF(vec3 clr, vec2 coord)
{

	float blurFactor = 0.075;
	float gaux2Mipmapping = 25.0;

	vec3 blurSample = clr;

#ifdef depthOfField

	vec2 aspectcorrect = vec2(1.0, aspectRatio);

	float getDepth = texture2D(depthtex2, coord.st).x;
	float focus = getDepth - centerDepthSmooth;
	float factor = focus * blurFactor;

#ifdef chromaticAberration

	vec2 chromAberation = vec2(factor * 0.75, 0.0);

	for (int i = 0; i < 28; i++)
	{

		blurSample.r += texture2D(gaux1, coord.st + coordsOffsets28[i] * aspectcorrect * factor + chromAberation, gaux2Mipmapping * abs(focus)).r;
		blurSample.g += texture2D(gaux1, coord.st + coordsOffsets28[i] * aspectcorrect * factor, gaux2Mipmapping * abs(focus)).g;
		blurSample.b += texture2D(gaux1, coord.st + coordsOffsets28[i] * aspectcorrect * factor - chromAberation, gaux2Mipmapping * abs(focus)).b;
	}

#else

	for (int i = 0; i < 28; i++)
	{

		blurSample += texture2D(gaux1, coord.st + coordsOffsets28[i] * aspectcorrect * factor, gaux2Mipmapping * abs(focus)).rgb;
	}

#endif

	blurSample /= 28.0;

#endif

	return blurSample;
}

vec3 calcNaturalBloom(vec3 clr, vec2 coord)
{

	float bloomMinIntensity = 0.25;
	float bloomMaxIntensity = 0.6;
	float bloomCover = 0.3;

	float bloomIntensity = mix(bloomMinIntensity, bloomMaxIntensity, dynamicTonemapping(1.0, true, false, false));

#ifdef bloom

	vec2 aspectcorrect = vec2(1.0, aspectRatio);

	vec3 bloomColor = vec3(0.0);
	bloomColor += max(texture2D(gaux1, coord.st, 4.0).rgb - bloomCover, 0.0);
	bloomColor += max(texture2D(gaux1, coord.st, 4.5).rgb - bloomCover, 0.0);
	bloomColor += max(texture2D(gaux1, coord.st, 5.0).rgb - bloomCover, 0.0);
	bloomColor += max(texture2D(gaux1, coord.st, 5.5).rgb - bloomCover, 0.0);
	bloomColor += max(texture2D(gaux1, coord.st, 6.0).rgb - bloomCover, 0.0);
	bloomColor += max(texture2D(gaux1, coord.st, 6.5).rgb - bloomCover, 0.0);
	bloomColor += max(texture2D(gaux1, coord.st, 7.0).rgb - bloomCover, 0.0);

	bloomColor /= 7.0;

	float luma = dot(bloomColor, vec3(1.0));
	vec3 chroma = bloomColor - luma;
	bloomColor = (chroma * (1.0 - bloomCover)) + luma;

	clr *= 1.0 - vec3ToFloat(bloomColor) * bloomIntensity;
	clr += bloomColor * bloomIntensity;

#endif

	return clr;
}

float hex(float lensDist, float size)
{

#define deg2rad 3.14159 / 180.

	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 pos1 = tpos.xy / tpos.z * lensDist;
	vec2 lightPos = pos1 * 0.5 + 0.5;

	vec2 uv = texcoord.xy;

	size *= (viewHeight + viewWidth) / 1920.0;

	vec2 v = (lightPos / texel) - (uv / texel);

	vec2 topBottomEdge = vec2(0., 1.);
	vec2 leftEdges = vec2(cos(30. * deg2rad), sin(30. * deg2rad));
	vec2 rightEdges = vec2(cos(30. * deg2rad), sin(30. * deg2rad));

	float dot1 = dot(abs(v), topBottomEdge);
	float dot2 = dot(abs(v), leftEdges);
	float dot3 = dot(abs(v), rightEdges);

	float dotMax = max(max((dot1), (dot2)), (dot3));

	return max(0.0, mix(0.0, mix(1.0, 1.0, floor(size - dotMax * 1.1 + 0.99)), floor(size - dotMax + 0.99))) * 0.1;
}

vec3 drawLensFlare(vec3 clr, vec3 sunClr, vec2 lPos)
{

	float lensFlareIntensity = 0.06;

#ifdef lensFlare

	vec2 centerLight = abs(lPos * 2.0 - 1.0);
	float distof = min(centerLight.x, centerLight.y);
	float fading = clamp(1.0 - distof * distof * 1.25, 0.0, 1.0);

	if (fading > 0.01 && isEyeInWater < 0.9)
	{

		float sunvisibility = texture2D(gaux1, vec2(0.0015)).a * fading;

		if (sunvisibility > 0.01)
		{

			float hex1 = min(hex(0.5, 50.0), 0.99);
			float hex2 = min(hex(0.2, 40.0), 0.99);
			float hex3 = min(hex(-0.1, 30.0), 0.99);
			float hex4 = min(hex(-0.4, 60.0), 0.99);
			float hex5 = min(hex(-0.7, 70.0), 0.99);
			float hex6 = min(hex(-1.0, 90.0), 0.99);

			float distHex = max(1.0 - pow(distance(texcoord.st, vec2(0.5)), 1.0) * 2.5, 0.0);

			vec3 hexColor = vec3(0.0);
			hexColor += hex1 * vec3(0.1, 0.4, 1.0);
			hexColor += hex2 * vec3(0.2, 0.6, 1.0);
			hexColor += hex3 * vec3(0.6, 0.8, 1.0);
			hexColor += hex4 * vec3(0.2, 0.6, 1.0);
			hexColor += hex5 * vec3(0.15, 0.45, 1.0);
			hexColor += hex6 * vec3(0.1, 0.4, 1.0);

			clr.rgb += hexColor * lensFlareIntensity * distHex * getTruePos() * sunvisibility * TimeDay * DayToNightFading * (1.0 - rainStrength);

			float anamorphicLens = pow(max(1.0 - yDistAxis(0.0), 0.0), 15.0);
			float distAL = pow(max(1.0 - smoothCircleDist(1.0), 0.0), 1.5 / sunvisibility);

			vec3 alColor = vec3(0.0);
			alColor += vec3(0.2, 0.5, 1.0) * TimeDay;
			alColor += vec3(0.6, 0.7, 1.0) * TimeMidnight;

			clr.rgb += anamorphicLens * alColor * lensFlareIntensity * 2.0 * distAL * getTruePos() * DayToNightFading * (1.0 - rainStrength);
		}
	}

#endif

	return clr;
}

vec3 renderGodrays(vec3 clr, vec3 sunClr, vec3 fragpos, vec2 lPos)
{

	float godraysIntensity = 0.3;
	float godraysExposure = 2.0;
	int godraysSamples = 50;
	float godraysDensity = 1.0;
	float godraysMipmapping = 1.0;

#ifdef godrays

	float grSample = 0.0;

	vec2 grCoord = texcoord.st;
	vec2 deltaTextCoord = vec2(texcoord.st - lPos.xy);
	deltaTextCoord *= 1.0 / float(godraysSamples) * godraysDensity;

	float sunVector = max(dot(normalize(fragpos.xyz), lightVector), 0.0);
	float calcSun = pow(sunVector, 7.5);

	for (int i = 0; i < godraysSamples; i++)
	{

		grCoord -= deltaTextCoord;
		grSample += texture2D(gaux1, grCoord, godraysMipmapping).a;
	}

	godraysIntensity = mix(godraysIntensity, godraysIntensity / 5.0, TimeMidnight);

	grSample /= float(godraysSamples) / godraysIntensity;

	clr = mix(clr, sunClr * godraysExposure, grSample * calcSun * getTruePos() * DayToNightFading * (1.0 - weatherRatio));

#else

	vec2 centerLight = abs(lPos * 2.0 - 1.0);
	float distof = min(centerLight.x, centerLight.y);
	float fading = clamp(1.0 - distof * distof * 1.25, 0.0, 1.0);

	if (fading > 0.01)
	{

		float sunvisibility = texture2D(gaux1, vec2(0.0015)).a * fading;

		float sunGlow = pow(max(1.0 - smoothCircleDist(1.0), 0.0), 3.0 / sunvisibility) * 1.3;

		godraysIntensity = mix(godraysIntensity, godraysIntensity / 4.0, TimeMidnight);

		clr = mix(clr, sunClr * godraysExposure, sunGlow * godraysIntensity * getTruePos() * DayToNightFading * (1.0 - weatherRatio));
	}

#endif

	return clr;
}

void main()
{

	const bool gaux1MipmapEnabled = true; // For godrays.

	vec2 newTexcoord = underwaterRefraction(texcoord.xy);

	vec4 color = texture2D(gaux1, newTexcoord.xy);

	vec4 fragposition = gbufferProjectionInverse * vec4(texcoord.s * 2.0f - 1.0f, texcoord.t * 2.0f - 1.0f, 2.0f * getDepth - 1.0f, 1.0f);
	fragposition /= fragposition.w;

	vec4 tpos = vec4(sunPosition, 1.0) * gbufferProjection;
	tpos = vec4(tpos.xyz / tpos.w, 1.0);
	vec2 pos1 = tpos.xy / tpos.z;
	vec2 lightPos = pos1 * 0.5 + 0.5;

	vec3 gr_Color = vec3(0.0);
	gr_Color += vec3(1.0, 0.8, 0.6) * TimeSunrise;
	gr_Color += vec3(1.0, 0.95, 0.9) * TimeNoon;
	gr_Color += vec3(1.0, 0.8, 0.6) * TimeSunset;
	gr_Color += vec3(0.6, 0.7, 1.0) * TimeMidnight;

	color.rgb = doChromaticAberration(color.rgb, newTexcoord);
	color.rgb = renderDOF(color.rgb, newTexcoord);
	color.rgb = calcNaturalBloom(color.rgb, newTexcoord);
	color.rgb = drawRainDrops(color.rgb, newTexcoord);
	color.rgb = renderGodrays(color.rgb, gr_Color, fragposition.xyz, lightPos);
	color.rgb = doCameraNoise(color.rgb);
	color.rgb = drawLensFlare(color.rgb, gr_Color, lightPos);
	color.rgb = doTonemapping(color.rgb);
	color.rgb = doVignette(color.rgb);
	color.rgb = doCinematicMode(color.rgb);

	gl_FragColor = color;
}
