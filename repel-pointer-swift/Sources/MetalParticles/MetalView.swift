import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MouseTrackingMTKView()
        context.coordinator.renderer = mtkView.renderer
        context.coordinator.renderer?.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
    }
    
    class Coordinator: NSObject {
        var parent: MetalView
        var renderer: Renderer?
        
        init(_ parent: MetalView) {
            self.parent = parent
            // We create a temporary MTKView just to initialize the renderer?
            // Or better, we initialize renderer in makeNSView.
            // But we need the renderer here to assign as delegate.
            // Let's defer renderer creation to makeNSView or handle it differently.
            // Actually, the renderer needs the view to set up device etc.
            super.init()
        }
    }
}

// Custom MTKView to handle mouse events
class MouseTrackingMTKView: MTKView {
    var renderer: Renderer?
    
    init() {
        super.init(frame: .zero, device: nil)
        // Renderer initialization
        self.renderer = Renderer(metalKitView: self)
        self.delegate = self.renderer
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .activeAlways]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        
        // Convert to backing coordinates (pixels) for the shader
        // Flip Y coordinate: macOS origin is bottom-left, Metal is top-left
        let scale = self.layer?.contentsScale ?? 1.0
        let flippedY = self.bounds.height - location.y
        let pixelLocation = CGPoint(x: location.x * scale, y: flippedY * scale)
        
        renderer?.updateMousePosition(pixelLocation)
    }
}
