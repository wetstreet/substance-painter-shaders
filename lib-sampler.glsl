import lib-defines.glsl
import lib-sparse.glsl

const vec3  DEFAULT_BASE_COLOR       = vec3(0.5);
const float DEFAULT_ROUGHNESS        = 0.3;
const float DEFAULT_METALLIC         = 0.0;
const float DEFAULT_ANISOTROPY_LEVEL = 0.0;
const float DEFAULT_ANISOTROPY_ANGLE = 0.0;
const float DEFAULT_OPACITY          = 1.0;
const float DEFAULT_AO               = 1.0;
const float DEFAULT_SPECULAR_LEVEL   = 0.5;
const float DEFAULT_HEIGHT           = 0.0;
const float DEFAULT_DISPLACEMENT     = 0.0;
const float DEFAULT_SCATTERING       = 0.0;

//: param auto ao_blending_mode
uniform int ao_blending_mode;
//: param auto texture_ao
uniform SamplerSparse base_ao_tex;
//: param auto channel_ao
uniform SamplerSparse ao_tex;

//: param custom {
//:   "default": 0.75,
//:   "label": "AO Intensity",
//:   "min": 0.00,
//:   "max": 1.0,
//:   "group": "Common Parameters"
//: }
uniform float ao_intensity;

//: param auto shadow_mask_enable
uniform bool sm_enable;
//: param auto shadow_mask_opacity
uniform float sm_opacity;
//: param auto shadow_mask
uniform sampler2D sm_tex;
//: param auto screen_size
uniform vec4 screen_size;

float getGlossiness(vec4 sampledValue)
{
  return sampledValue.r + (1.0 - DEFAULT_ROUGHNESS) * (1.0 - sampledValue.g);
}

float getGlossiness(SamplerSparse sampler, SparseCoord coord)
{
  return getGlossiness(textureSparse(sampler, coord));
}

float getRoughness(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_ROUGHNESS * (1.0 - sampledValue.g);
}

float getRoughness(SamplerSparse sampler, SparseCoord coord)
{
  return getRoughness(textureSparse(sampler, coord));
}

float getMetallic(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_METALLIC * (1.0 - sampledValue.g);
}

float getMetallic(SamplerSparse sampler, SparseCoord coord)
{
  return getMetallic(textureSparse(sampler, coord));
}

float getAnisotropyLevel(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_ANISOTROPY_LEVEL * (1.0 - sampledValue.g);
}

float getAnisotropyLevel(SamplerSparse sampler, SparseCoord coord)
{
  return getAnisotropyLevel(textureSparse(sampler, coord));
}

float getAnisotropyAngle(vec4 sampledValue)
{
  return M_2PI * (sampledValue.r + DEFAULT_ANISOTROPY_ANGLE * (1.0 - sampledValue.g));
}

float getAnisotropyAngle(SamplerSparse sampler, SparseCoord coord)
{
  // Manual trilinear filtering
  float level = max(0.0, textureSparseQueryLod(sampler, coord) + uvtile_lod_bias);
  int level0 = int(level);
  int level1 = level0 + 1;

  ivec2 texSize0 = ivec2(sampler.size.xy) >> level0;
  ivec2 texSize1 = texSize0 >> 1;
  ivec2 itex_coord0 = ivec2(coord.tex_coord * vec2(texSize0));
  ivec2 itex_coord1 = ivec2(coord.tex_coord * vec2(texSize1));

  // Assuming tex sizes are pow of 2, we can do the fast modulo
  ivec2 texSizeMask0 = texSize0 - ivec2(1);
  ivec2 texSizeMask1 = texSize1 - ivec2(1);

  // Fetch the 8 samples needed
  float a000 = getAnisotropyAngle(texelFetch(sampler.tex,  itex_coord0                & texSizeMask0, level0));
  float a001 = getAnisotropyAngle(texelFetch(sampler.tex, (itex_coord0 + ivec2(1, 0)) & texSizeMask0, level0)) - a000;
  float a010 = getAnisotropyAngle(texelFetch(sampler.tex, (itex_coord0 + ivec2(0, 1)) & texSizeMask0, level0)) - a000;
  float a011 = getAnisotropyAngle(texelFetch(sampler.tex, (itex_coord0 + ivec2(1, 1)) & texSizeMask0, level0)) - a000;
  float a100 = getAnisotropyAngle(texelFetch(sampler.tex,  itex_coord1                & texSizeMask1, level1)) - a000;
  float a101 = getAnisotropyAngle(texelFetch(sampler.tex, (itex_coord1 + ivec2(1, 0)) & texSizeMask1, level1)) - a000;
  float a110 = getAnisotropyAngle(texelFetch(sampler.tex, (itex_coord1 + ivec2(0, 1)) & texSizeMask1, level1)) - a000;
  float a111 = getAnisotropyAngle(texelFetch(sampler.tex, (itex_coord1 + ivec2(1, 1)) & texSizeMask1, level1)) - a000;

  // Detect if the angle warps inside the filtering footprint, and fix it
  a001 += abs(a001) > M_PI ? sign(a001) * -M_2PI + a000 : a000;
  a010 += abs(a010) > M_PI ? sign(a010) * -M_2PI + a000 : a000;
  a011 += abs(a011) > M_PI ? sign(a011) * -M_2PI + a000 : a000;
  a100 += abs(a100) > M_PI ? sign(a100) * -M_2PI + a000 : a000;
  a101 += abs(a101) > M_PI ? sign(a101) * -M_2PI + a000 : a000;
  a110 += abs(a110) > M_PI ? sign(a110) * -M_2PI + a000 : a000;
  a111 += abs(a111) > M_PI ? sign(a111) * -M_2PI + a000 : a000;

  // Trilinear blending of the samples
  vec2 t0 = coord.tex_coord * vec2(texSize0) - vec2(itex_coord0);
  vec2 t1 = coord.tex_coord * vec2(texSize1) - vec2(itex_coord1);
  return mix(
    mix(mix(a000, a001, t0.x), mix(a010, a011, t0.x), t0.y),
    mix(mix(a100, a101, t1.x), mix(a110, a111, t1.x), t1.y),
    level - float(level0));
}

float getOpacity(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_OPACITY * (1.0 - sampledValue.g);
}

float getOpacity(SamplerSparse sampler, SparseCoord coord)
{
  return getOpacity(textureSparse(sampler, coord));
}

float getHeight(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_HEIGHT * (1.0 - sampledValue.g);
}

float getHeight(SamplerSparse sampler, SparseCoord coord)
{
  return getHeight(textureSparse(sampler, coord));
}

float getDisplacement(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_DISPLACEMENT * (1.0 - sampledValue.g);
}

float getDisplacement(SamplerSparse sampler, SparseCoord coord)
{
  return getDisplacement(textureSparse(sampler, coord));
}

float getAO(SparseCoord coord, bool is_premult)
{
  vec2 ao_lookup = textureSparse(base_ao_tex, coord).ra;
  float ao = ao_lookup.x + DEFAULT_AO * (1.0 - ao_lookup.y);

  if (ao_tex.is_set) {
    ao_lookup = textureSparse(ao_tex, coord).rg;
    if (!is_premult) ao_lookup.x *= ao_lookup.y;
    float channel_ao = ao_lookup.x + DEFAULT_AO * (1.0 - ao_lookup.y);
    if (ao_blending_mode == BlendingMode_Replace) {
      ao = channel_ao;
    } else if (ao_blending_mode == BlendingMode_Multiply) {
      ao *= channel_ao;
    }
  }

  // Modulate AO value by AO_intensity
  return mix(1.0, ao, ao_intensity);
}

float getAO(SparseCoord coord)
{
  return getAO(coord, true);
}

float getSpecularLevel(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_SPECULAR_LEVEL * (1.0 - sampledValue.g);
}

float getSpecularLevel(SamplerSparse sampler, SparseCoord coord)
{
  return getSpecularLevel(textureSparse(sampler, coord));
}

float getShadowFactor()
{
  float shadowFactor = 1.0;

  if (sm_enable) {
    vec2 screenCoord = (gl_FragCoord.xy * vec2(screen_size.z, screen_size.w));
    vec2 shadowSample = texture(sm_tex, screenCoord).xy;
    // shadowSample.x / shadowSample.y is the normalized shadow factor.
    // shadowSample.x may already be normalized, shadowSample.y contains 0.0 in this case.
    shadowFactor = shadowSample.y == 0.0 ? shadowSample.x : shadowSample.x / shadowSample.y;
  }

  return mix(1.0, shadowFactor, sm_opacity);
}

vec3 getBaseColor(vec4 sampledValue)
{
  return sampledValue.rgb + DEFAULT_BASE_COLOR * (1.0 - sampledValue.a);
}

vec3 getBaseColor(SamplerSparse sampler, SparseCoord coord)
{
  return getBaseColor(textureSparse(sampler, coord));
}

vec3 getDiffuse(vec4 sampledValue)
{
  return getBaseColor(sampledValue);
}

vec3 getDiffuse(SamplerSparse sampler, SparseCoord coord)
{
  return getDiffuse(textureSparse(sampler, coord));
}

vec3 getSpecularColor(vec4 sampledValue)
{
  vec3 specColor = sampledValue.rgb + DEFAULT_BASE_COLOR * (1.0 - sampledValue.a);
  vec3 defaultF0 = mix(vec3(0.04), specColor, DEFAULT_METALLIC);
  return mix(specColor, defaultF0, (1.0 - sampledValue.a));
}

vec3 getSpecularColor(SamplerSparse sampler, SparseCoord coord)
{
  return getSpecularColor(textureSparse(sampler, coord));
}

vec2 generateAnisotropicRoughness(float roughness, float anisoLevel)
{
  return vec2(roughness, roughness / sqrt(max(1e-8, 1.0 - anisoLevel)));
}

vec3 generateDiffuseColor(vec3 baseColor, float metallic)
{
  return baseColor * (1.0 - metallic);
}

vec3 generateSpecularColor(float specularLevel, vec3 baseColor, float metallic)
{
  return mix(vec3(0.08 * specularLevel), baseColor, metallic);
}

vec3 generateSpecularColor(vec3 baseColor, float metallic)
{
  return mix(vec3(0.04), baseColor, metallic);
}

float getScattering(vec4 sampledValue)
{
  return sampledValue.r + DEFAULT_SCATTERING * (1.0 - sampledValue.g);
}

float getScattering(SamplerSparse sampler, SparseCoord coord)
{
  return getScattering(textureSparse(sampler, coord));
}
