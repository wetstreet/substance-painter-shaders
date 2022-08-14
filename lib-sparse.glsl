#ifdef FEATURE_SPARSE_TEXTURE
//: param auto material_lod_check_needed
uniform bool material_lod_check_needed = false;
//: param auto material_lod_mask
uniform usampler2D material_lod_mask;
#endif // FEATURE_SPARSE_TEXTURE
//: param auto uvtile_reference_sampler
uniform sampler2D uvtile_reference_sampler;
//: param auto uvtile_size
uniform vec2 uvtile_size;
//: param auto uvtile_inverse_size
uniform vec2 uvtile_inverse_size;
//: param auto uvtile_lod_bias
uniform float uvtile_lod_bias;

struct SamplerSparse {
  sampler2D tex;
  vec4 size; // width, height, 1/width, 1/height
  bool is_set; // a boolean indicating whether the texture is in the texture set or not
  uvec3 lod_mask_select; // masking operations description allowing to retrieve loaded mipmaps information
};

struct SparseCoord {
  vec2 tex_coord;
  vec2 dfdx;
  vec2 dfdy;
  float lod;
  uint material_lod_mask;
};


#if defined(SHADER_FRAGMENT)

SparseCoord getSparseCoord(vec2 tex_coord) {
  SparseCoord res;
  res.tex_coord = tex_coord;
  res.dfdx = dFdx(tex_coord);
  res.dfdy = dFdy(tex_coord);
#ifdef FEATURE_SPARSE_TEXTURE
  res.material_lod_mask = material_lod_check_needed ?
    textureLod(material_lod_mask,tex_coord,0.0).r :
    0u;
  res.lod = getLodFromReferenceSampler(tex_coord);
#endif // FEATURE_SPARSE_TEXTURE
  return res;
}
#endif

SparseCoord getSparseCoordLod0(vec2 tex_coord) {
  SparseCoord res;
  res.tex_coord = tex_coord;
  res.dfdx = vec2(0.0);
  res.dfdy = vec2(0.0);
#ifdef FEATURE_SPARSE_TEXTURE
  res.material_lod_mask = material_lod_check_needed ?
    textureLod(material_lod_mask,tex_coord,0.0).r :
    0u;
  res.lod = 0.0;
#endif // FEATURE_SPARSE_TEXTURE
  return res;
}

#if defined(SHADER_FRAGMENT)

float textureSparseQueryLod(SamplerSparse sampler, SparseCoord coord) {
#ifdef FEATURE_SPARSE_TEXTURE
  float lodfix = coord.lod;
  if (material_lod_check_needed) {
    lodfix = getFixedSparseLod(getTextureLodMask(sampler.lod_mask_select, coord.material_lod_mask), lodfix);
  }
  return lodfix-uvtile_lod_bias;
#else // FEATURE_SPARSE_TEXTURE
  return textureQueryLod(sampler.tex, coord.tex_coord).y-uvtile_lod_bias;
#endif // FEATURE_SPARSE_TEXTURE
}
#endif // SHADER_FRAGMENT

void textureSparseQueryGrad(out vec2 dfdx, out vec2 dfdy, SamplerSparse sampler, SparseCoord coord) {
#ifdef FEATURE_SPARSE_TEXTURE
  if (material_lod_check_needed) {
    float lodfix = getFixedSparseLod(getTextureLodMask(sampler.lod_mask_select, coord.material_lod_mask), coord.lod);
    if (coord.lod!=lodfix) {
      // Fix dfdx dfdy, take account offset, no more anisotropy
      vec2 ddfix = exp2(lodfix-uvtile_lod_bias) * uvtile_inverse_size;
      dfdx = vec2(ddfix.x,0.0);
      dfdy = vec2(0.0,ddfix.y);
      return;
    }
  }
#endif // FEATURE_SPARSE_TEXTURE
  dfdx = coord.dfdx;
  dfdy = coord.dfdy;
}

vec4 textureSparse(SamplerSparse sampler, SparseCoord coord) {
  vec2 dfdx,dfdy;
  textureSparseQueryGrad(dfdx, dfdy, sampler, coord);
  return textureGrad(sampler.tex, coord.tex_coord, dfdx, dfdy);
}

void textureSparseOffsets(SamplerSparse sampler, SparseCoord coord, vec2 offsets[N], out vec4 results[N]) {
  vec2 dfdx,dfdy;
  textureSparseQueryGrad(dfdx, dfdy, sampler, coord);
  for(int i = 0; i < N; ++i) {
    results[i] = textureGrad(sampler.tex, coord.tex_coord + offsets[i], dfdx, dfdy);
  }
}
