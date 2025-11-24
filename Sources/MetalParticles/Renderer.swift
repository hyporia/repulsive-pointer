import Metal
import MetalKit
import simd
import Foundation

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var originalPosition: SIMD2<Float>
}

struct Uniforms {
    var mousePosition: SIMD2<Float>
    var time: Float
    var resolution: SIMD2<Float>
    var repulsionRadius: Float
    var repulsionStrength: Float
}

class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var computePipelineState: MTLComputePipelineState!
    var renderPipelineState: MTLRenderPipelineState!
    
    var particleBuffer: MTLBuffer!
    var uniformsBuffer: MTLBuffer!
    
    var particles: [Particle] = []
    let particleCount = 10000
    
    var viewportSize: CGSize = .zero
    var mousePosition: CGPoint = .zero
    
    init?(metalKitView: MTKView) {
        super.init()
        
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        metalKitView.device = device
        metalKitView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        metalKitView.delegate = self
        
        buildPipelineStates()
        initParticles()
    }
    
    func buildPipelineStates() {
        var library: MTLLibrary?
        // Load the library
        do {
            library = try device.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            print("Note: Could not load default library from bundle: \(error)")
            return
        }
        
        guard let lib = library else {
            print("Could not create default library")
            return
        }
        
        // Compute Pipeline
        guard let kernelFunction = lib.makeFunction(name: "updateParticles") else {
            print("Could not create kernel function")
            return
        }
        
        do {
            computePipelineState = try device.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("Compute pipeline error: \(error)")
        }
        
        // Render Pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = lib.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = lib.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Render pipeline error: \(error)")
        }
    }
    
    func initParticles() {
        // Initial distribution will be handled in mtkView(_:drawableSizeWillChange:)
        // or we can just allocate here and set positions later.
        // Let's allocate buffer first.
        
        let bufferSize = MemoryLayout<Particle>.stride * particleCount
        particleBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)
    }
    
    func resetParticles(size: CGSize) {
        guard let buffer = particleBuffer else { return }
        
        var pointer = buffer.contents().bindMemory(to: Particle.self, capacity: particleCount)
        
        let cols = Int(sqrt(Double(particleCount)))
        let rows = particleCount / cols
        
        let spacingX = Float(size.width) / Float(cols)
        let spacingY = Float(size.height) / Float(rows)
        
        for i in 0..<particleCount {
            let col = i % cols
            let row = i / cols
            
            let x = Float(col) * spacingX + spacingX * 0.5
            let y = Float(row) * spacingY + spacingY * 0.5
            
            let pos = SIMD2<Float>(x, y)
            
            pointer.pointee = Particle(position: pos, velocity: .zero, originalPosition: pos)
            pointer = pointer.advanced(by: 1)
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
        resetParticles(size: size)
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }
        
        // Update Uniforms
        var uniforms = Uniforms(
            mousePosition: SIMD2<Float>(Float(mousePosition.x), Float(mousePosition.y)),
            time: Float(CACurrentMediaTime()),
            resolution: SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height)),
            repulsionRadius: 150.0,
            repulsionStrength: 2.0
        )
        
        // Compute Pass
        if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeEncoder.setComputePipelineState(computePipelineState)
            computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
            computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            
            let threadGroupSize = MTLSize(width: computePipelineState.threadExecutionWidth, height: 1, depth: 1)
            let threadGroups = MTLSize(width: (particleCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1)
            
            computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            computeEncoder.endEncoding()
        }
        
        // Render Pass
        if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            
            renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
            renderEncoder.endEncoding()
        }
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func updateMousePosition(_ point: CGPoint) {
        // Convert view coordinates to pixel coordinates if necessary,
        // but here we assume the point passed is already relative to the view.
        // We need to scale it to the drawable size (Retina display).
        
        // Note: The point passed from SwiftUI will be in points.
        // The shader expects pixels.
        // We'll handle scaling in the view.
        self.mousePosition = point
    }
}
