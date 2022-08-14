import lib-sampler.glsl

//: param auto is_2d_view
uniform bool isTextureView;

//: param auto channel_displacement
uniform SamplerSparse displacement_tex;

//: param custom { "label": "Enable", "default": false, "group": "Parallax Occlusion Mapping" }
uniform bool usePOM;

//: param custom { "label": "Strength", "default": 1.0, "min": 0.01, "max": 10.0, "group": "Parallax Occlusion Mapping" }
uniform float pomStrength;

//: param custom { "label": "Minimum samples", "default": 4, "min": 1, "max": 64, "group": "Parallax Occlusion Mapping" }
uniform int minPOMSamples;

//: param custom { "label": "Maximum samples", "default": 16, "min": 1, "max": 64, "group": "Parallax Occlusion Mapping" }
uniform int maxPOMSamples;

vec2 getParallaxOffset(SparseCoord coord, vec3 viewTS)
{
  if (!usePOM || isTextureView || !displacement_tex.is_set) return vec2(0.0);

  vec2 dfdx,dfdy;
  textureSparseQueryGrad(dfdx, dfdy, displacement_tex, coord);

  // Convention: 1.0 is top, -1.0 is bottom - POM is always inward, no extrusion
  int nbSteps = int(mix(maxPOMSamples, minPOMSamples, viewTS.z));
  float amplitude = 4.0 * pomStrength / (HEIGHT_FACTOR * abs(viewTS.z) * nbSteps);
  vec3 rayStep = vec3(-amplitude * viewTS.xy, -2.0 / nbSteps);

  // Raymarch until we cross the surface
  vec3 rayPos = vec3(coord.tex_coord, 1.0);
  float prevHeight;
  float currHeight = getDisplacement(textureGrad(displacement_tex.tex, rayPos.xy, dfdx, dfdy));
  int i = 0;
  do {
    rayPos += rayStep;
    prevHeight = currHeight;
    currHeight = getDisplacement(textureGrad(displacement_tex.tex, rayPos.xy, dfdx, dfdy));
    i++;
  } while (i < nbSteps && currHeight < rayPos.z);

  // Binary search with linear interpolation to refine intersection
  vec3 prevRayPos = rayPos - rayStep;
  vec3 newRayPos = prevRayPos;
  float newHeight = prevHeight;
  i = 0;
  while (i < 3 && abs(newHeight - newRayPos.z) > 1e-3) {
    float prevDelta = prevRayPos.z - prevHeight;
    float delta = currHeight - rayPos.z;
    newRayPos = (prevDelta * rayPos + delta * prevRayPos) / (prevDelta + delta);
    newHeight = getDisplacement(textureGrad(displacement_tex.tex, newRayPos.xy, dfdx, dfdy));

    if (newHeight > newRayPos.z) {
      currHeight = newHeight;
      rayPos = newRayPos;
    } else {
      prevHeight = newHeight;
      prevRayPos = newRayPos;
    }

    i++;
  }

  return newRayPos.xy - coord.tex_coord;
}

void applyParallaxOffset(inout V2F inputs, vec3 viewTS)
{
  vec2 offset = getParallaxOffset(inputs.sparse_coord, viewTS);
  if (any(notEqual(offset,vec2(0.0)))) {
    inputs.tex_coord += offset;
    inputs.sparse_coord = getSparseCoord(inputs.tex_coord);
  }
}
