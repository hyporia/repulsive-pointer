#include "Renderer.hpp"
#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

// Forward declaration of the delegate
@interface AppDelegate
    : NSObject <NSApplicationDelegate, NSWindowDelegate, MTKViewDelegate>
@end

@implementation AppDelegate {
  NSWindow *_window;
  MTKView *_view;
  Renderer *_renderer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  NSRect frame = NSMakeRect(0, 0, 800, 600);
  NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                     NSWindowStyleMaskResizable |
                     NSWindowStyleMaskMiniaturizable;

  _window = [[NSWindow alloc] initWithContentRect:frame
                                        styleMask:style
                                          backing:NSBackingStoreBuffered
                                            defer:NO];
  [_window setTitle:@"Repel Pointer C++"];
  [_window makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
  [_window setDelegate:self];

  _view = [[MTKView alloc] initWithFrame:frame];
  _window.contentView = _view;

  _view.delegate = self;

  _renderer = new Renderer(_view);

  // Add Mouse Tracking
  NSTrackingArea *trackingArea = [[NSTrackingArea alloc]
      initWithRect:_view.bounds
           options:NSTrackingMouseMoved | NSTrackingActiveInKeyWindow |
                   NSTrackingInVisibleRect
             owner:self
          userInfo:nil];
  [_view addTrackingArea:trackingArea];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

// MTKViewDelegate methods
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
  if (_renderer) {
    _renderer->drawableSizeWillChange(view, size);
  }
}

- (void)drawInMTKView:(MTKView *)view {
  if (_renderer) {
    _renderer->draw(view);
  }
}

// Mouse events
- (void)mouseMoved:(NSEvent *)event {
  NSPoint location = [event locationInWindow];
  // Convert to view coordinates if needed, but here window coords map closely
  // since view fills window. However, we need to respect DPI scaling for retina
  // potentially if the renderer uses pixels. The Swift code used logic that
  // eventually passed points to shaders. BUT the shader expects pixels (or
  // uniform coordinate space). Let's pass the point in backing store
  // coordinates? Swift code: `resetParticles` used `size` which is drawableSize
  // (pixels). `updateMousePosition` in Swift took the point directly from
  // MouseEvent. In shader: `dist = distance(currentPos, mousePos)` `currentPos`
  // is in pixels (from `resetParticles`).

  // So we need to convert window point to backing/pixel coordinates.
  if (_view) {
    NSPoint pointInView = [_view convertPoint:location fromView:nil];
    // Flip Y to match Top-Left origin expected by shader
    pointInView.y = _view.bounds.size.height - pointInView.y;

    NSPoint pointInBacking = [_view convertPointToBacking:pointInView];
    // Flip Y because Metal coordinates are Y-down in 2D or center-based?
    // Wait, standard Metal is Normalized Device Coords (NDC) [-1, 1],
    // BUT the shader does this:
    // `float2 clipPos = (pixelPos / resolution) * 2.0 - 1.0;`
    // `clipPos.y = -clipPos.y; // Flip Y for Metal`
    // So `pixelPos` logic assumes 0,0 is top-left or bottom-left?
    // NSView (0,0) is Bottom-Left.
    // `resetParticles`:
    // y = row * spacingY ...
    // If row 0 is bottom, then particles start at bottom.

    // Let's assume standard Cocoa coordinates (Bottom-Left 0,0).
    // If we want Mouse 0,0 to be Top-Left (like generic inputs might be), we'd
    // flip. But let's check Swift: Text: `clipPos.y = -clipPos.y`. If input
    // `pixelPos` Y is 0 (bottom), clip Y becomes -1. Negated -> 1 (Top). So Y=0
    // is Top in Clip Space? Metal Clip Space: (-1,-1) is Bottom-Left? No, (-1,
    // -1) is usually Bottom-Left in Metal? Actually Metal Clip Space: (-1, -1)
    // Bottom-Left, (1, 1) Top-Right. If Y=0 -> ClipY = -1 -> Negated = +1
    // (Top). So Y=0 in pixel space maps to Top of screen. So Pixel Space 0,0 is
    // Top-Left?

    // But AppKit `initParticles`:
    // col/row loops.
    // If standard iteration, row 0 is first.

    // Let's just try to pass the backing point for now with Y flipped relative
    // to View Height to match Top-Left origin if necessary. Usually
    // `locationInWindow` is Bottom-Left. If we want Top-Left, we do Height - Y.
    // Let's start with raw converted point. The user can adjust if inverted.

    // Actually, let's look at `mousePos` in shader.
    // `dist = distance(currentPos, mousePos)`
    // If `currentPos` is in "Bottom-Left" coordinates and `mousePos` is
    // "Bottom-Left", it works. We just need consistency.

    _renderer->updateMousePosition(pointInBacking);
  }
}

@end

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];

    AppDelegate *delegate = [[AppDelegate alloc] init];
    [app setDelegate:delegate];
    [app run];
  }
  return 0;
}
