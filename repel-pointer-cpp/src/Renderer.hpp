#ifndef Renderer_hpp
#define Renderer_hpp

#include "ShaderDefinitions.h"

// Forward declarations instead of including metal-cpp headers
// This avoids conflicts when included from Objective-C++ files
namespace MTL {
class Device;
class CommandQueue;
class ComputePipelineState;
class RenderPipelineState;
class Buffer;
} // namespace MTL

namespace CA {
class MetalLayer;
}

#include <string>

class Renderer {
public:
  Renderer(CA::MetalLayer *layer);
  ~Renderer();

  void draw();
  void drawableSizeWillChange(float width, float height);
  void updateMousePosition(float x, float y);

  void setLayer(CA::MetalLayer *layer);

private:
  void buildPipelineStates();
  void initParticles();
  void resetParticles(float width, float height);
  std::string readFile(const std::string &filepath);

  MTL::Device *_device;
  MTL::CommandQueue *_commandQueue;
  MTL::ComputePipelineState *_computePipelineState;
  MTL::RenderPipelineState *_renderPipelineState;
  MTL::Buffer *_particleBuffer;

  CA::MetalLayer *_layer;

  int _particleCount = 10000;
  float _viewportWidth;
  float _viewportHeight;
  float _mouseX;
  float _mouseY;
};

#endif /* Renderer_hpp */
