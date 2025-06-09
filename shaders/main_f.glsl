// #version 120

#include "./settings.glsl"


uniform sampler2D lightmap;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D texture;

varying vec2 lmcoord;
varying vec2 texcoord;
varying vec4 glcolor;
varying vec4 shadowPos;
varying vec3 normals_face;

uniform float sunAngle;
uniform vec3 shadowLightPosition;

// added fog
uniform float fogStart;
uniform float fogEnd;
uniform vec3 fogColor;
uniform float far;

varying vec3 viewPos_v3;

//fix artifacts when colored shadows are enabled
const bool shadowcolor0Nearest = true;
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;

//only using this include for shadowMapResolution,
//since that has to be declared in the fragment stage in order to do anything.
#include "/distort.glsl"

void main() {
	
	vec4 color = texture2D(texture, texcoord) * glcolor;
	vec2 lm = lmcoord;

	#if LIGHTING_STYLES == 0
		if (shadowPos.w > 0.0) {
			#if COLORED_SHADOWS == 0
				if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
			#else
				if (texture2D(shadowtex1, shadowPos.xy).r < shadowPos.z) {
			#endif
				lm.y *= SHADOW_BRIGHTNESS;
			}
			else {
				lm.y = mix(31.0 / 32.0 * SHADOW_BRIGHTNESS, 31.0 / 32.0, sqrt(shadowPos.w));
				#if COLORED_SHADOWS == 1
					if (texture2D(shadowtex0, shadowPos.xy).r < shadowPos.z) {
						vec4 shadowLightColor = texture2D(shadowcolor0, shadowPos.xy);
						shadowLightColor.rgb = mix(vec3(1.0), shadowLightColor.rgb, shadowLightColor.a);
						color.rgb *= shadowLightColor.rgb;
					}
			#endif
			}
		}
	#endif

	vec3 fire_color = vec3(0.25, 0.25, 0.);
	vec3 sky_color = vec3(0., 0., 1.);

	#if LIGHTING_STYLES == 1
		if (sunAngle > 0.5)
		{
			sky_color = vec3(0.);
		}

		color.rgb = color.rgb * (fire_color * lm.x + sky_color * lm.y); 
	#endif

	float lightDot = clamp(dot(normalize(shadowLightPosition), normals_face), 0., 1.);
	color.rgb = color.rgb * (
		fire_color * lm.x
		+ texture2D(lightmap, lm).y * lm.y
		+ lightDot
	);

	// fog color (far)
	float fog_amount_border = clamp((length(viewPos_v3) - (FOG_BORDER_START * far)) / ((1. - FOG_BORDER_START) * far), 0., 1.);
	float fog_amount = max(
		clamp((length(viewPos_v3) - FOG_START) / (FOG_END - FOG_START), 0., 1.),
		fog_amount_border
	);

	color.rgb = mix(
		color.rgb,
		mix(fogColor.rgb, vec3(color.b), 0.3),
		(fog_amount / 2)
	);

	#if BERSEK_MOD == 1
		float average_color = (color.r + color.b + color.g) / 3.0;
		color.rgb = mix(color.rgb, vec3(average_color), 1.0);
	#endif

	color *= texture2D(lightmap, lm);

	/* DRAWBUFFERS:0 */
	gl_FragData[0] = color; //gcolor
}
