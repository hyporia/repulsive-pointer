// AppDelegate.mm - Minimal Objective-C++ shim for AppKit window management
// The Metal rendering is handled by the pure C++ Renderer class

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CADisplayLink.h>
#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/QuartzCore.h>

// Forward declare the C++ types we need
namespace CA {
class MetalLayer;
}

// Include only the header with forward declarations
#include "Renderer.hpp"

// Custom NSView that uses CAMetalLayer as its backing layer
@interface MetalView : NSView
@property(nonatomic, readonly) CAMetalLayer *metalLayer;
@end

@implementation MetalView

+ (Class)layerClass {
  return [CAMetalLayer class];
}

- (CALayer *)makeBackingLayer {
  CAMetalLayer *layer = [CAMetalLayer layer];
  layer.contentsScale = [NSScreen mainScreen].backingScaleFactor;
  return layer;
}

- (CAMetalLayer *)metalLayer {
  return (CAMetalLayer *)self.layer;
}

- (BOOL)wantsUpdateLayer {
  return YES;
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@end

@implementation AppDelegate {
  NSWindow *_window;
  MetalView *_view;
  Renderer *_renderer;
  CADisplayLink *_displayLink;
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

  // Create a MetalView with CAMetalLayer as its backing layer
  _view = [[MetalView alloc] initWithFrame:frame];
  _view.wantsLayer = YES;
  _window.contentView = _view;

  // Configure the metal layer
  CAMetalLayer *metalLayer = _view.metalLayer;
  metalLayer.drawableSize =
      CGSizeMake(frame.size.width * metalLayer.contentsScale,
                 frame.size.height * metalLayer.contentsScale);

  // Create the C++ Renderer with the metal layer
  CA::MetalLayer *cppLayer = (__bridge CA::MetalLayer *)metalLayer;
  _renderer = new Renderer(cppLayer);

  // Update viewport size
  CGSize drawableSize = metalLayer.drawableSize;
  _renderer->drawableSizeWillChange(drawableSize.width, drawableSize.height);

  // Add Mouse Tracking
  NSTrackingArea *trackingArea = [[NSTrackingArea alloc]
      initWithRect:_view.bounds
           options:NSTrackingMouseMoved | NSTrackingActiveInKeyWindow |
                   NSTrackingInVisibleRect
             owner:self
          userInfo:nil];
  [_view addTrackingArea:trackingArea];

  // Setup display link for rendering
  _displayLink = [_window displayLinkWithTarget:self
                                       selector:@selector(render:)];
  [_displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                     forMode:NSRunLoopCommonModes];
}

- (void)render:(CADisplayLink *)displayLink {
  if (_renderer) {
    _renderer->draw();
  }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
  if (_displayLink) {
    [_displayLink invalidate];
    _displayLink = nil;
  }
  delete _renderer;
  _renderer = nullptr;
}

// Window resize handling
- (void)windowDidResize:(NSNotification *)notification {
  if (_view && _renderer) {
    CAMetalLayer *metalLayer = _view.metalLayer;
    metalLayer.drawableSize =
        CGSizeMake(_view.bounds.size.width * metalLayer.contentsScale,
                   _view.bounds.size.height * metalLayer.contentsScale);
    CGSize drawableSize = metalLayer.drawableSize;
    _renderer->drawableSizeWillChange(drawableSize.width, drawableSize.height);
  }
}

// Mouse events
- (void)mouseMoved:(NSEvent *)event {
  if (_renderer && _view) {
    NSPoint location = [event locationInWindow];
    NSPoint pointInView = [_view convertPoint:location fromView:nil];

    // Convert to backing coordinates (for Retina displays)
    CAMetalLayer *metalLayer = _view.metalLayer;
    CGFloat scale = metalLayer.contentsScale;
    float x = pointInView.x * scale;
    float y = pointInView.y * scale;

    // Flip Y coordinate (Cocoa is bottom-left origin, we want top-left)
    y = metalLayer.drawableSize.height - y;

    _renderer->updateMousePosition(x, y);
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
