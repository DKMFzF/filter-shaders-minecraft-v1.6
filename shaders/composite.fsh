#version 120

#define DRAW_SHADOW_MAP gcolor //Configures which buffer to draw to the screen [gcolor shadowcolor0 shadowtex0 shadowtex1]

// colors
#define BLUE_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]
#define GREEN_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]
#define GRAY_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]
#define RED_AMOUNT 0.25 //[0.0 0.25 0.5 0.75 1.0]

// effects
#define EFFECT_SEPIA 0 //[0 1]
#define EFFECT_INVERT 0 //[0 1]
#define EFFECT_OLD_FILM 0 //[0 1]
#define EFFECT_CONTRAST 0.0 //[0.0 0.25 0.5 0.75 1.0]
#define EFFECT_BRIGHTNESS 0.0 //[0.0 0.25 0.5 0.75 1.0]
#define EFFECT_SATURATION 0.0 //[0.0 0.25 0.5 0.75 1.0]

// blur effect
#define EFFECT_BLUR 0.0 //[0.0 0.25 0.5 0.75 1.0]
#define EFFECT_BLUR_RADIUS 0.002 // [0.001 0.002 0.003 0.005]
#define BLUR_CENTER_RADIUS 0.2 // [0.1 0.2 0.3 0.4 0.5]
#define BLUR_TRANSITION 0.1 // [0.05 0.1 0.15]

uniform float frameTimeCounter;
uniform sampler2D gcolor;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

varying vec2 texcoord;

vec3 make_color(in vec3 base_color, in vec3 mix_color, in float amount)
{
	return mix(base_color, mix_color, amount);
}

vec3 sepia(in vec3 color)
{
	vec3 sepia = vec3(1.2, 1.0, 0.8);
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	return make_color(color, vec3(gray) * sepia, 0.75);
}

vec3 invert(in vec3 color)
{
	return vec3(1.0) - color; 
}

vec3 oldFilm(vec3 color, vec2 uv)
{
	float grain = fract(sin(dot(uv, vec2(13, 78.2))) * 44000);
	color += grain * 0.25;

	vec2 center = uv - 0.5;
	float vignette = 1.0 - dot(center, center);
	color *= vignette * 1.25;
	
	return color;
}

vec3 effectContrast(in vec3 color, in float value)
{
	return 0.5 + (1.0 + value) * (color - 0.5);
}

vec3 effectBrightness(in vec3 color, in float value)
{
	return color + value;
}

vec3 effectSaturation(vec3 color, float value)
{
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	return mix(vec3(gray), color, 1.0 + value);
}

vec3 effectSelectiveBlur(
	sampler2D tex,
	vec2 uv,
	float radius,
	float centerRadius,
	float transition
) {
	vec2 center = vec2(0.5, 0.5);
	float distanceToCenter = length(uv - center);
	
	float blurStrength = smoothstep(centerRadius, centerRadius + transition, distanceToCenter);

	if (blurStrength <= 0.0) return texture2D(tex, uv).rgb;

	vec3 sum = vec3(0.0);
	int samples = 0;

	int maxSamples = int(mix(1, 4, blurStrength));

	for(int i = -maxSamples; i <= maxSamples; i++) {
		for(int j = -maxSamples; j <= maxSamples; j++) {
			sum += texture2D(tex, uv + vec2(i, j) * radius * blurStrength).rgb;
			samples++;
		}
	}

	return sum / float(samples);
}

void main()
{
	vec3 color = texture2D(DRAW_SHADOW_MAP, texcoord).rgb;
	
	// settings colors
	color = make_color(color, vec3(0., 0., 1.), BLUE_AMOUNT);
	color = make_color(color, vec3(0., 1., 0.), GREEN_AMOUNT);
	color = make_color(color, vec3(1., 0., 0.), RED_AMOUNT);

	// gray color
	float average_color = (color.r + color.b + color.g) / 3.0;
	color = make_color(color, vec3(average_color), GRAY_AMOUNT);

	// effects
	if (EFFECT_SEPIA > 0) color = sepia(color);
	if (EFFECT_INVERT > 0) color = invert(color);
	if (EFFECT_OLD_FILM > 0) color = oldFilm(color, texcoord);
	if (EFFECT_CONTRAST > 0) color = effectContrast(color, EFFECT_CONTRAST);
	if (EFFECT_BRIGHTNESS > 0) color = effectBrightness(color, EFFECT_BRIGHTNESS);
	if (EFFECT_SATURATION > 0) color = effectSaturation(color, EFFECT_SATURATION);
	if (EFFECT_BLUR > 0) color = effectSelectiveBlur(
		DRAW_SHADOW_MAP, 
		texcoord, 
		EFFECT_BLUR_RADIUS, 
		BLUR_CENTER_RADIUS, 
		BLUR_TRANSITION
	);

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = vec4(color, 1.0); //gcolor
}
