#ifndef ShaderDefinitions_h
#define ShaderDefinitions_h

#include <simd/simd.h>

struct Particle {
    vector_float2 position;
    vector_float2 velocity;
    vector_float2 originalPosition;
};

struct Uniforms {
    vector_float2 mousePosition;
    float time;
    vector_float2 resolution;
    float repulsionRadius;
    float repulsionStrength;
};

#endif /* ShaderDefinitions_h */
