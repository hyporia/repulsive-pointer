#ifndef Renderer_hpp
#define Renderer_hpp

#include "ShaderDefinitions.h"
#import <MetalKit/MetalKit.h>
#include <vector>

class Renderer {
public:
  Renderer(MTKView *view);
  ~Renderer();

  void draw(MTKView *view);
  void drawableSizeWillChange(MTKView *view, CGSize size);
  void updateMousePosition(CGPoint point);

private:
  void buildPipelineStates();
  void initParticles();
  void resetParticles(CGSize size);

  id<MTLDevice> _device;
  id<MTLCommandQueue> _commandQueue;
  id<MTLComputePipelineState> _computePipelineState;
  id<MTLRenderPipelineState> _renderPipelineState;

  id<MTLBuffer> _particleBuffer;

  int _particleCount = 5000;
  CGSize _viewportSize;
  CGPoint _mousePosition;
};

#endif /* Renderer_hpp */
