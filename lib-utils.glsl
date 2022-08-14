vec3 tonemapSCurve(vec3 value, float sigma, float n)
{
  vec3 pow_value = pow(value, vec3(n));
  return pow_value / (pow_value + pow(sigma, n));
}

float sRGB2linear(float x)
{
  return x <= 0.04045 ?
    x * 0.0773993808 : // 1.0/12.92
    pow((x + 0.055) / 1.055, 2.4);
}

vec3 sRGB2linear(vec3 rgb)
{
  return vec3(
    sRGB2linear(rgb.r),
    sRGB2linear(rgb.g),
    sRGB2linear(rgb.b));
}

vec4 sRGB2linear(vec4 rgba)
{
  return vec4(sRGB2linear(rgba.rgb), rgba.a);
}

float linear2sRGB(float x)
{
  return x <= 0.0031308 ?
      12.92 * x :
      1.055 * pow(x, 0.41666) - 0.055;
}

vec3 linear2sRGB(vec3 rgb)
{
  return vec3(
      linear2sRGB(rgb.r),
      linear2sRGB(rgb.g),
      linear2sRGB(rgb.b));
}

vec4 linear2sRGB(vec4 rgba)
{
  return vec4(linear2sRGB(rgba.rgb), rgba.a);
}

//: param auto conversion_linear_to_srgb
uniform bool convert_to_srgb_opt;
float linear2sRGBOpt(float x)
{
  return convert_to_srgb_opt ? linear2sRGB(x) : x;
}

vec3 linear2sRGBOpt(vec3 rgb)
{
  return convert_to_srgb_opt ? linear2sRGB(rgb) : rgb;
}

vec4 linear2sRGBOpt(vec4 rgba)
{
  return convert_to_srgb_opt ? linear2sRGB(rgba) : rgba;
}

uniform int output_conversion_method;
float convertOutput(float x)
{
	if (output_conversion_method == 0) return x;
	else if (output_conversion_method == 1) return linear2sRGB(x);
	else return sRGB2linear(x);
}

vec3 convertOutput(vec3 rgb)
{
	if (output_conversion_method == 0) return rgb;
	else if (output_conversion_method == 1) return linear2sRGB(rgb);
	else return sRGB2linear(rgb);
}

vec4 convertOutput(vec4 rgba)
{
	if (output_conversion_method == 0) return rgba;
	else if (output_conversion_method == 1) return linear2sRGB(rgba);
	else return sRGB2linear(rgba);
}

import lib-bayer.glsl

float getDitherThreshold(uvec2 coords)
{
  return bayerMatrix8(coords);
}

vec4 RGB2Gray(vec4 rgba)
{
  float gray = 0.299 * rgba.r + 0.587 * rgba.g + 0.114 * rgba.b;
  return vec4(vec3(gray), rgba.a);
}

float specularOcclusionCorrection(float diffuseOcclusion, float metallic, float roughness)
{
  return mix(diffuseOcclusion, 1.0, metallic * (1.0 - roughness) * (1.0 - roughness));
}
