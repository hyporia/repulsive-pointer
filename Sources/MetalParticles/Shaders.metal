#include <metal_stdlib>
// Targeting Metal 3.1+

#include "ShaderDefinitions.h"

using namespace metal;

// Compute kernel to update particle positions
kernel void updateParticles(device Particle *particles [[buffer(0)]],
                            constant Uniforms &uniforms [[buffer(1)]],
                            uint id [[thread_position_in_grid]]) {
    
    Particle particle = particles[id];
    
    float2 currentPos = particle.position;
    float2 originalPos = particle.originalPosition;
    float2 mousePos = uniforms.mousePosition;
    
    // Calculate distance to mouse
    float dist = distance(currentPos, mousePos);
    
    // Repulsion force
    float2 force = float2(0.0);
    if (dist < uniforms.repulsionRadius) {
        float2 dir = normalize(currentPos - mousePos);
        float strength = (1.0 - dist / uniforms.repulsionRadius) * uniforms.repulsionStrength;
        force = dir * strength;
    }
    
    // Spring back to original position
    float2 springForce = (originalPos - currentPos) * 0.05; // Stiffness
    
    // Apply forces
    // Simple Euler integration (ignoring mass for simplicity)
    particle.velocity += force + springForce;
    particle.velocity *= 0.90; // Damping
    
    particle.position += particle.velocity;
    
    particles[id] = particle;
}

// Vertex shader
struct VertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              device const Particle *particles [[buffer(0)]],
                              constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    
    Particle particle = particles[vertexID];
    
    // Convert pixel coordinates to clip space (-1 to 1)
    float2 pixelPos = particle.position;
    float2 resolution = uniforms.resolution;
    
    float2 clipPos = (pixelPos / resolution) * 2.0 - 1.0;
    clipPos.y = -clipPos.y; // Flip Y for Metal
    
    float speed = length(particle.velocity);
    float maxSpeed = 10.0; // Adjust this value to control sensitivity
    float intensity = clamp(speed / maxSpeed, 0.0, 1.0);
    
    float4 baseColor = float4(0.6, 0.8, 1.0, 1.0); // Light blue
    float4 targetColor = float4(1.0, 0.2, 0.2, 1.0); // Reddish
    
    out.position = float4(clipPos, 0.0, 1.0);
    out.pointSize = 3.0; // Particle size
    out.color = mix(baseColor, targetColor, intensity);
    
    return out;
}

// Fragment shader
fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
