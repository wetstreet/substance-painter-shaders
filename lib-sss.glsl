import lib-sampler.glsl

//: param auto channel_scattering
uniform SamplerSparse sss_tex;

//: param auto scene_original_radius
uniform float sssSceneScale;

//: param custom {
//:   "label": "Enable",
//:   "default": true,
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>Enable the Subsurface Scattering. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform bool sssEnabled;

//: param custom {
//:   "default": 1,
//:   "label": "Scattering Type",
//:   "widget": "combobox",
//:   "values": {
//:     "Translucent": 0,
//:     "Skin": 1
//:   },
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>Skin or Translucent/Generic. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform int sssType;

//: param custom {
//:   "default": 0.5,
//:   "label": "Scale",
//:   "min": 0.01,
//:   "max": 1.0,
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>Controls the radius/depth of the light absorption in the material. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform float sssScale;

//: param custom {
//:   "default": [0.701, 0.301, 0.305],
//:   "label": "Color",
//:   "widget": "color",
//:   "group": "Subsurface Scattering Parameters",
//:   "description": "<html><head/><body><p>The color of light when absorbed by the material. It needs to be activated in the Display Settings and a Scattering channel needs to be present for these parameters to have an effect.</p></body></html>"
//: }
uniform vec3 sssColor;

vec4 getSSSCoefficients(float scattering) {
  if (sssEnabled) {
    vec3 sss = sssScale / sssSceneScale * scattering * sssColor;
    return vec4(sss, sss == vec3(0.0) ? 0.0 : 1.0);
  }
  return vec4(0.0);
}
vec4 getSSSCoefficients(SparseCoord coord) {
  if (sssEnabled) {
    return getSSSCoefficients(getScattering(sss_tex, coord));
  }
  return vec4(0.0);
}
