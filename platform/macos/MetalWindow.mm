#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include "MetalWindow.h"

#include <iostream>

@interface VeyraMetalView : NSView
@property(nonatomic, strong) id<MTLDevice> metalDevice;
@property(nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property(nonatomic, strong) id<MTLRenderPipelineState> pipeline;
@property(nonatomic, strong) NSTimer *frameTimer;
- (void)renderFrame;
@end

@implementation VeyraMetalView

- (CALayer *)makeBackingLayer
{
    return [CAMetalLayer layer];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    self.wantsLayer = YES;

    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    self.metalDevice = MTLCreateSystemDefaultDevice();
    if (self.metalDevice == nil) {
        std::cerr << "Metal window: no Metal device is available.\n";
        return;
    }

    self.commandQueue = [self.metalDevice newCommandQueue];
    metalLayer.device = self.metalDevice;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metalLayer.framebufferOnly = YES;
    metalLayer.opaque = YES;

    static NSString * const shaderSource =
        @"#include <metal_stdlib>\n"
         "using namespace metal;\n"
         "struct VertexOut { float4 position [[position]]; };\n"
         "vertex VertexOut veyraWindowVertex(uint id [[vertex_id]]) {\n"
         "  constexpr float2 p[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };\n"
         "  VertexOut out; out.position = float4(p[id], 0.0, 1.0); return out;\n"
         "}\n"
         "fragment float4 veyraWindowFragment() { return float4(0.12, 0.20, 0.42, 1.0); }\n";

    NSError *error = nil;
    id<MTLLibrary> library =
        [self.metalDevice newLibraryWithSource:shaderSource options:nil error:&error];
    if (library == nil) {
        std::cerr << "Metal window: shader compilation failed: "
                  << (error.localizedDescription.UTF8String ?: "unknown error") << '\n';
        return;
    }

    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = [library newFunctionWithName:@"veyraWindowVertex"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"veyraWindowFragment"];
    descriptor.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
    self.pipeline = [self.metalDevice newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (self.pipeline == nil) {
        std::cerr << "Metal window: pipeline creation failed: "
                  << (error.localizedDescription.UTF8String ?: "unknown error") << '\n';
        return;
    }

    [self updateDrawableSize];
    self.frameTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0 / 60.0)
                                                       target:self
                                                     selector:@selector(renderFrame)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self updateDrawableSize];
}

- (void)viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];
    [self updateDrawableSize];
}

- (void)updateDrawableSize
{
    if (self.window == nil || ![self.layer isKindOfClass:[CAMetalLayer class]]) return;
    const CGFloat scale = self.window.backingScaleFactor;
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    metalLayer.contentsScale = scale;
    metalLayer.drawableSize = CGSizeMake(self.bounds.size.width * scale,
                                         self.bounds.size.height * scale);
}

- (void)renderFrame
{
    if (self.pipeline == nil || self.commandQueue == nil) return;
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    id<CAMetalDrawable> drawable = [metalLayer nextDrawable];
    if (drawable == nil) return;

    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.025, 0.035, 0.07, 1.0);

    id<MTLCommandBuffer> command = [self.commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:self.pipeline];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];
    [command presentDrawable:drawable];
    [command commit];
}

@end

@interface VeyraAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSWindow *window;
@end

@implementation VeyraAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    const NSRect frame = NSMakeRect(0, 0, 960, 600);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Veyra for macOS — Metal presentation test";
    self.window.delegate = self;
    self.window.contentView = [[VeyraMetalView alloc] initWithFrame:frame];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

@end

int runMetalWindow()
{
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyRegular];
        VeyraAppDelegate *delegate = [[VeyraAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
        return 0;
    }
}
