#include "Renderer.hpp"
#include <cmath>
#include <fstream>
#include <iostream>
#include <sstream>
#include <unistd.h>

Renderer::Renderer(MTKView *view) {
  _device = MTLCreateSystemDefaultDevice();
  view.device = _device;
  view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
  view.clearColor = MTLClearColorMake(0.1, 0.1, 0.1, 1.0);

  _commandQueue = [_device newCommandQueue];

  _viewportSize = view.drawableSize;
  if (_viewportSize.width == 0 || _viewportSize.height == 0) {
    _viewportSize = view.bounds.size;
    // Handle backing scale if needed, but simple fallback is good for now
    CGFloat scale = [NSScreen mainScreen].backingScaleFactor;
    _viewportSize.width *= scale;
    _viewportSize.height *= scale;
  }
  _mousePosition = CGPointZero;

  buildPipelineStates();
  initParticles();
  resetParticles(_viewportSize);
}

Renderer::~Renderer() {
  // ARC handles release
}

std::string readFile(const std::string &filepath) {
  std::ifstream t(filepath);
  if (!t.is_open()) {
    std::cerr << "Failed to open " << filepath
              << ". Current working directory: " << getcwd(NULL, 0)
              << std::endl;
    return "";
  }
  std::stringstream buffer;
  buffer << t.rdbuf();
  return buffer.str();
}

void Renderer::buildPipelineStates() {
  // Load shader source
  std::string shaderSource = readFile("src/Shaders.metal");
  std::string headerSource = readFile("src/ShaderDefinitions.h");

  if (shaderSource.empty() || headerSource.empty()) {
    std::cerr << "Could not load shader sources. Ensure you are running from "
                 "the project root."
              << std::endl;
    return;
  }

  // Manual #include replacement
  std::string search = "#include \"ShaderDefinitions.h\"";
  size_t pos = shaderSource.find(search);
  if (pos != std::string::npos) {
    shaderSource.replace(pos, search.length(), headerSource);
  }

  NSError *error = nil;
  NSString *source = [NSString stringWithUTF8String:shaderSource.c_str()];
  id<MTLLibrary> library = [_device newLibraryWithSource:source
                                                 options:nil
                                                   error:&error];

  if (!library) {
    std::cerr << "Library compile error: " <<
        [[error localizedDescription] UTF8String] << std::endl;
    return;
  }

  // Compute Pipeline
  id<MTLFunction> kernelFunction =
      [library newFunctionWithName:@"updateParticles"];
  if (!kernelFunction) {
    std::cerr << "Could not find kernel function" << std::endl;
    return;
  }

  MTLComputePipelineDescriptor *computeDescriptor =
      [[MTLComputePipelineDescriptor alloc] init];
  computeDescriptor.computeFunction = kernelFunction;
  computeDescriptor.label = @"Particle Update";

  _computePipelineState =
      [_device newComputePipelineStateWithDescriptor:computeDescriptor
                                             options:MTLPipelineOptionNone
                                          reflection:nil
                                               error:&error];

  if (!_computePipelineState) {
    std::cerr << "Compute pipeline error: " <<
        [[error localizedDescription] UTF8String] << std::endl;
  }

  // Render Pipeline
  MTLRenderPipelineDescriptor *renderDescriptor =
      [[MTLRenderPipelineDescriptor alloc] init];
  renderDescriptor.vertexFunction =
      [library newFunctionWithName:@"vertexShader"];
  renderDescriptor.fragmentFunction =
      [library newFunctionWithName:@"fragmentShader"];
  renderDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

  _renderPipelineState =
      [_device newRenderPipelineStateWithDescriptor:renderDescriptor
                                              error:&error];

  if (!_renderPipelineState) {
    std::cerr << "Render pipeline error: " <<
        [[error localizedDescription] UTF8String] << std::endl;
  }
}

void Renderer::initParticles() {
  NSUInteger bufferSize = sizeof(Particle) * _particleCount;
  _particleBuffer = [_device newBufferWithLength:bufferSize
                                         options:MTLResourceStorageModeShared];
}

void Renderer::resetParticles(CGSize size) {
  if (!_particleBuffer)
    return;

  Particle *particles = (Particle *)[_particleBuffer contents];

  int cols = std::sqrt(_particleCount);
  int rows = _particleCount / cols;

  float spacingX = size.width / cols;
  float spacingY = size.height / rows;

  for (int i = 0; i < _particleCount; i++) {
    int col = i % cols;
    int row = i / cols;

    float x = col * spacingX + spacingX * 0.5f;
    float y = row * spacingY + spacingY * 0.5f;

    particles[i].position = {x, y};
    particles[i].velocity = {0, 0};
    particles[i].originalPosition = {x, y};
  }
}

void Renderer::drawableSizeWillChange(MTKView *view, CGSize size) {
  _viewportSize = size;
  resetParticles(size);
}

void Renderer::updateMousePosition(CGPoint point) { _mousePosition = point; }

void Renderer::draw(MTKView *view) {
  id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
  id<MTLRenderCommandEncoder> renderEncoder = nil;
  id<MTLComputeCommandEncoder> computeEncoder = nil;

  // Update Uniforms
  Uniforms uniforms;
  uniforms.mousePosition = {(float)_mousePosition.x, (float)_mousePosition.y};
  uniforms.time = CACurrentMediaTime();
  uniforms.resolution = {(float)_viewportSize.width,
                         (float)_viewportSize.height};
  uniforms.repulsionRadius = 300.0f;
  uniforms.repulsionStrength = 2.0f;

  // Compute Pass
  if (_computePipelineState) {
    computeEncoder = [commandBuffer computeCommandEncoder];
    [computeEncoder setComputePipelineState:_computePipelineState];
    [computeEncoder setBuffer:_particleBuffer offset:0 atIndex:0];
    [computeEncoder setBytes:&uniforms length:sizeof(Uniforms) atIndex:1];

    NSUInteger w = _computePipelineState.threadExecutionWidth;
    MTLSize threadGroupSize = MTLSizeMake(w, 1, 1);
    MTLSize threadGroups = MTLSizeMake((_particleCount + w - 1) / w, 1, 1);

    [computeEncoder dispatchThreadgroups:threadGroups
                   threadsPerThreadgroup:threadGroupSize];
    [computeEncoder endEncoding];
  }

  // Render Pass
  MTLRenderPassDescriptor *passDescriptor = view.currentRenderPassDescriptor;
  if (passDescriptor) {
    renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    if (renderEncoder && _renderPipelineState) {
      [renderEncoder setRenderPipelineState:_renderPipelineState];
      [renderEncoder setVertexBuffer:_particleBuffer offset:0 atIndex:0];
      [renderEncoder setVertexBytes:&uniforms
                             length:sizeof(Uniforms)
                            atIndex:1];

      [renderEncoder drawPrimitives:MTLPrimitiveTypePoint
                        vertexStart:0
                        vertexCount:_particleCount];
      [renderEncoder endEncoding];
    }
  }

  [commandBuffer presentDrawable:view.currentDrawable];
  [commandBuffer commit];
}
