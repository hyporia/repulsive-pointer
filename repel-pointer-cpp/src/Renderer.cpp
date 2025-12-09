#include "Renderer.hpp"

// Include metal-cpp headers only in the .cpp file
#include <Foundation/Foundation.hpp>
#include <Metal/Metal.hpp>
#include <QuartzCore/QuartzCore.hpp>

#include <cmath>
#include <fstream>
#include <iostream>
#include <sstream>
#include <unistd.h>

std::string Renderer::readFile(const std::string &filepath) {
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

Renderer::Renderer(CA::MetalLayer *layer) {
  _device = MTL::CreateSystemDefaultDevice();
  _layer = layer;

  if (_layer && _device) {
    _layer->setDevice(_device);
    _layer->setPixelFormat(MTL::PixelFormatBGRA8Unorm);
  }

  _commandQueue = _device->newCommandQueue();

  _viewportWidth = 800.0f;
  _viewportHeight = 600.0f;
  _mouseX = 0.0f;
  _mouseY = 0.0f;

  buildPipelineStates();
  initParticles();
  resetParticles(_viewportWidth, _viewportHeight);
}

Renderer::~Renderer() {
  if (_particleBuffer)
    _particleBuffer->release();
  if (_computePipelineState)
    _computePipelineState->release();
  if (_renderPipelineState)
    _renderPipelineState->release();
  if (_commandQueue)
    _commandQueue->release();
  if (_device)
    _device->release();
}

void Renderer::setLayer(CA::MetalLayer *layer) {
  _layer = layer;
  if (_layer && _device) {
    _layer->setDevice(_device);
    _layer->setPixelFormat(MTL::PixelFormatBGRA8Unorm);
  }
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

  NS::Error *error = nullptr;
  NS::String *source =
      NS::String::string(shaderSource.c_str(), NS::UTF8StringEncoding);
  MTL::Library *library = _device->newLibrary(source, nullptr, &error);

  if (!library) {
    std::cerr << "Library compile error: "
              << (error ? error->localizedDescription()->utf8String()
                        : "unknown")
              << std::endl;
    return;
  }

  // Compute Pipeline
  NS::String *kernelName =
      NS::String::string("updateParticles", NS::UTF8StringEncoding);
  MTL::Function *kernelFunction = library->newFunction(kernelName);
  if (!kernelFunction) {
    std::cerr << "Could not find kernel function" << std::endl;
    library->release();
    return;
  }

  _computePipelineState =
      _device->newComputePipelineState(kernelFunction, &error);

  if (!_computePipelineState) {
    std::cerr << "Compute pipeline error: "
              << (error ? error->localizedDescription()->utf8String()
                        : "unknown")
              << std::endl;
  }
  kernelFunction->release();

  // Render Pipeline
  MTL::RenderPipelineDescriptor *renderDescriptor =
      MTL::RenderPipelineDescriptor::alloc()->init();

  NS::String *vertexName =
      NS::String::string("vertexShader", NS::UTF8StringEncoding);
  NS::String *fragmentName =
      NS::String::string("fragmentShader", NS::UTF8StringEncoding);

  MTL::Function *vertexFunction = library->newFunction(vertexName);
  MTL::Function *fragmentFunction = library->newFunction(fragmentName);

  renderDescriptor->setVertexFunction(vertexFunction);
  renderDescriptor->setFragmentFunction(fragmentFunction);
  renderDescriptor->colorAttachments()->object(0)->setPixelFormat(
      MTL::PixelFormatBGRA8Unorm);

  _renderPipelineState =
      _device->newRenderPipelineState(renderDescriptor, &error);

  if (!_renderPipelineState) {
    std::cerr << "Render pipeline error: "
              << (error ? error->localizedDescription()->utf8String()
                        : "unknown")
              << std::endl;
  }

  if (vertexFunction)
    vertexFunction->release();
  if (fragmentFunction)
    fragmentFunction->release();
  renderDescriptor->release();
  library->release();
}

void Renderer::initParticles() {
  NS::UInteger bufferSize = sizeof(Particle) * _particleCount;
  _particleBuffer =
      _device->newBuffer(bufferSize, MTL::ResourceStorageModeShared);
}

void Renderer::resetParticles(float width, float height) {
  if (!_particleBuffer)
    return;

  Particle *particles = (Particle *)_particleBuffer->contents();

  int cols = std::sqrt(_particleCount);
  int rows = _particleCount / cols;

  float spacingX = width / cols;
  float spacingY = height / rows;

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

void Renderer::drawableSizeWillChange(float width, float height) {
  _viewportWidth = width;
  _viewportHeight = height;
  resetParticles(width, height);
}

void Renderer::updateMousePosition(float x, float y) {
  _mouseX = x;
  _mouseY = y;
}

void Renderer::draw() {
  NS::AutoreleasePool *pool = NS::AutoreleasePool::alloc()->init();

  if (!_layer) {
    pool->release();
    return;
  }

  CA::MetalDrawable *drawable = _layer->nextDrawable();
  if (!drawable) {
    pool->release();
    return;
  }

  MTL::CommandBuffer *commandBuffer = _commandQueue->commandBuffer();

  // Update Uniforms
  Uniforms uniforms;
  uniforms.mousePosition = {_mouseX, _mouseY};
  uniforms.time = 0.0f; // CACurrentMediaTime() would need CoreFoundation
  uniforms.resolution = {_viewportWidth, _viewportHeight};
  uniforms.repulsionRadius = 300.0f;
  uniforms.repulsionStrength = 2.0f;

  // Compute Pass
  if (_computePipelineState) {
    MTL::ComputeCommandEncoder *computeEncoder =
        commandBuffer->computeCommandEncoder();
    computeEncoder->setComputePipelineState(_computePipelineState);
    computeEncoder->setBuffer(_particleBuffer, 0, 0);
    computeEncoder->setBytes(&uniforms, sizeof(Uniforms), 1);

    NS::UInteger w = _computePipelineState->threadExecutionWidth();
    MTL::Size threadGroupSize = MTL::Size::Make(w, 1, 1);
    MTL::Size threadGroups =
        MTL::Size::Make((_particleCount + w - 1) / w, 1, 1);

    computeEncoder->dispatchThreadgroups(threadGroups, threadGroupSize);
    computeEncoder->endEncoding();
  }

  // Render Pass
  MTL::RenderPassDescriptor *passDescriptor =
      MTL::RenderPassDescriptor::alloc()->init();
  MTL::RenderPassColorAttachmentDescriptor *colorAttachment =
      passDescriptor->colorAttachments()->object(0);
  colorAttachment->setTexture(drawable->texture());
  colorAttachment->setLoadAction(MTL::LoadActionClear);
  colorAttachment->setClearColor(MTL::ClearColor::Make(0.1, 0.1, 0.1, 1.0));
  colorAttachment->setStoreAction(MTL::StoreActionStore);

  MTL::RenderCommandEncoder *renderEncoder =
      commandBuffer->renderCommandEncoder(passDescriptor);
  if (renderEncoder && _renderPipelineState) {
    renderEncoder->setRenderPipelineState(_renderPipelineState);
    renderEncoder->setVertexBuffer(_particleBuffer, 0, 0);
    renderEncoder->setVertexBytes(&uniforms, sizeof(Uniforms), 1);

    renderEncoder->drawPrimitives(MTL::PrimitiveTypePoint, NS::UInteger(0),
                                  NS::UInteger(_particleCount));
    renderEncoder->endEncoding();
  }

  commandBuffer->presentDrawable(drawable);
  commandBuffer->commit();

  passDescriptor->release();
  pool->release();
}
