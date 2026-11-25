#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

#include "MetalWindow.h"

#include <iostream>

static NSTextField *VeyraLabel(NSString *text, CGFloat size, NSColor *color, BOOL bold)
{
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

static NSColor *VeyraBackground(void)
{
    return [NSColor colorWithCalibratedRed:0.035 green:0.047 blue:0.075 alpha:1.0];
}

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
        std::cerr << "Metal preview: no Metal device is available.\n";
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
         "fragment float4 veyraWindowFragment() { return float4(0.035, 0.055, 0.105, 1.0); }\n";

    NSError *error = nil;
    id<MTLLibrary> library = [self.metalDevice newLibraryWithSource:shaderSource options:nil error:&error];
    if (library == nil) {
        std::cerr << "Metal preview shader failed: "
                  << (error.localizedDescription.UTF8String ?: "unknown error") << '\n';
        return;
    }

    MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
    descriptor.vertexFunction = [library newFunctionWithName:@"veyraWindowVertex"];
    descriptor.fragmentFunction = [library newFunctionWithName:@"veyraWindowFragment"];
    descriptor.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
    self.pipeline = [self.metalDevice newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (self.pipeline == nil) {
        std::cerr << "Metal preview pipeline failed: "
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
    metalLayer.drawableSize = CGSizeMake(self.bounds.size.width * scale, self.bounds.size.height * scale);
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
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.035, 0.055, 0.105, 1.0);

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

- (NSView *)makeStatusCardWithTitle:(NSString *)title detail:(NSString *)detail state:(NSString *)state
{
    NSView *card = [[NSView alloc] initWithFrame:NSZeroRect];
    card.wantsLayer = YES;
    card.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.055].CGColor;
    card.layer.cornerRadius = 10.0;

    NSTextField *heading = VeyraLabel(title, 15, [NSColor whiteColor], YES);
    NSTextField *description = VeyraLabel(detail, 12, [NSColor colorWithCalibratedWhite:0.78 alpha:1.0], NO);
    NSTextField *status = VeyraLabel(state, 11, [NSColor colorWithCalibratedRed:0.95 green:0.70 blue:0.30 alpha:1.0], YES);
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    description.translatesAutoresizingMaskIntoConstraints = NO;
    status.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:heading];
    [card addSubview:description];
    [card addSubview:status];

    [NSLayoutConstraint activateConstraints:@[
        [heading.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [heading.topAnchor constraintEqualToAnchor:card.topAnchor constant:13],
        [description.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [description.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:6],
        [description.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-12],
        [status.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [status.topAnchor constraintEqualToAnchor:description.bottomAnchor constant:9],
        [status.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-12]
    ]];
    return card;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    const NSRect frame = NSMakeRect(0, 0, 1120, 720);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled |
                                                         NSWindowStyleMaskClosable |
                                                         NSWindowStyleMaskMiniaturizable |
                                                         NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Veyra for macOS";
    self.window.minSize = NSMakeSize(900, 600);
    self.window.delegate = self;

    NSView *root = [[NSView alloc] initWithFrame:frame];
    root.wantsLayer = YES;
    root.layer.backgroundColor = VeyraBackground().CGColor;
    self.window.contentView = root;

    NSView *sidebar = [[NSView alloc] initWithFrame:NSZeroRect];
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    sidebar.wantsLayer = YES;
    sidebar.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.025 green:0.035 blue:0.060 alpha:1.0].CGColor;
    [root addSubview:sidebar];

    NSTextField *brand = VeyraLabel(@"VEYRA", 23, [NSColor whiteColor], YES);
    NSTextField *edition = VeyraLabel(@"MACOS  •  APPLE SILICON", 10,
                                      [NSColor colorWithCalibratedRed:0.40 green:0.62 blue:1.0 alpha:1.0], YES);
    brand.translatesAutoresizingMaskIntoConstraints = NO;
    edition.translatesAutoresizingMaskIntoConstraints = NO;
    [sidebar addSubview:brand];
    [sidebar addSubview:edition];

    NSArray<NSString *> *items = @[@"Overview", @"Xbox streaming", @"Video input", @"Enhancement", @"Settings"];
    NSStackView *navigation = [[NSStackView alloc] initWithFrame:NSZeroRect];
    navigation.orientation = NSUserInterfaceLayoutOrientationVertical;
    navigation.alignment = NSLayoutAttributeLeading;
    navigation.spacing = 18;
    navigation.translatesAutoresizingMaskIntoConstraints = NO;
    for (NSUInteger index = 0; index < items.count; ++index) {
        NSTextField *item = VeyraLabel(items[index], 13,
            index == 0 ? [NSColor colorWithCalibratedRed:0.48 green:0.66 blue:1.0 alpha:1.0]
                       : [NSColor colorWithCalibratedWhite:0.78 alpha:1.0], index == 0);
        [navigation addArrangedSubview:item];
    }
    [sidebar addSubview:navigation];

    NSView *main = [[NSView alloc] initWithFrame:NSZeroRect];
    main.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:main];

    NSTextField *eyebrow = VeyraLabel(@"YOUR MAC GAMING DISPLAY", 10,
        [NSColor colorWithCalibratedRed:0.43 green:0.65 blue:1.0 alpha:1.0], YES);
    NSTextField *heading = VeyraLabel(@"Welcome to Veyra", 28, [NSColor whiteColor], YES);
    NSTextField *subtitle = VeyraLabel(@"Native macOS foundation is running on Apple Silicon.", 13,
        [NSColor colorWithCalibratedWhite:0.72 alpha:1.0], NO);
    for (NSTextField *label in @[eyebrow, heading, subtitle]) {
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [main addSubview:label];
    }

    NSView *metalPanel = [[NSView alloc] initWithFrame:NSZeroRect];
    metalPanel.translatesAutoresizingMaskIntoConstraints = NO;
    metalPanel.wantsLayer = YES;
    metalPanel.layer.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.045].CGColor;
    metalPanel.layer.cornerRadius = 12.0;
    [main addSubview:metalPanel];

    NSTextField *previewTitle = VeyraLabel(@"Metal presentation surface", 14, [NSColor whiteColor], YES);
    previewTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [metalPanel addSubview:previewTitle];
    VeyraMetalView *preview = [[VeyraMetalView alloc] initWithFrame:NSZeroRect];
    preview.translatesAutoresizingMaskIntoConstraints = NO;
    preview.wantsLayer = YES;
    preview.layer.cornerRadius = 8.0;
    preview.layer.masksToBounds = YES;
    [metalPanel addSubview:preview];

    NSStackView *cards = [[NSStackView alloc] initWithFrame:NSZeroRect];
    cards.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    cards.distribution = NSStackViewDistributionFillEqually;
    cards.spacing = 12;
    cards.translatesAutoresizingMaskIntoConstraints = NO;
    [cards addArrangedSubview:[self makeStatusCardWithTitle:@"Xbox streaming"
        detail:@"Console connection and sign-in are not integrated yet." state:@"NOT CONNECTED"]];
    [cards addArrangedSubview:[self makeStatusCardWithTitle:@"Video input"
        detail:@"Capture-device discovery and live video are next." state:@"NOT CONNECTED"]];
    [cards addArrangedSubview:[self makeStatusCardWithTitle:@"Enhancement"
        detail:@"Apple-native upscaling is not implemented yet." state:@"NOT CONNECTED"]];
    [main addSubview:cards];

    NSTextField *footer = VeyraLabel(@"FOUNDATION BUILD  •  METAL DEVICE + PRESENTATION TEST", 10,
        [NSColor colorWithCalibratedWhite:0.55 alpha:1.0], YES);
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [main addSubview:footer];

    [NSLayoutConstraint activateConstraints:@[
        [sidebar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [sidebar.topAnchor constraintEqualToAnchor:root.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [sidebar.widthAnchor constraintEqualToConstant:210],
        [brand.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor constant:24],
        [brand.topAnchor constraintEqualToAnchor:sidebar.topAnchor constant:34],
        [edition.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],
        [edition.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:5],
        [navigation.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],
        [navigation.topAnchor constraintEqualToAnchor:edition.bottomAnchor constant:48],

        [main.leadingAnchor constraintEqualToAnchor:sidebar.trailingAnchor constant:34],
        [main.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-34],
        [main.topAnchor constraintEqualToAnchor:root.topAnchor constant:30],
        [main.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-24],

        [eyebrow.leadingAnchor constraintEqualToAnchor:main.leadingAnchor],
        [eyebrow.topAnchor constraintEqualToAnchor:main.topAnchor],
        [heading.leadingAnchor constraintEqualToAnchor:eyebrow.leadingAnchor],
        [heading.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:8],
        [subtitle.leadingAnchor constraintEqualToAnchor:heading.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:5],

        [metalPanel.leadingAnchor constraintEqualToAnchor:main.leadingAnchor],
        [metalPanel.trailingAnchor constraintEqualToAnchor:main.trailingAnchor],
        [metalPanel.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:22],
        [metalPanel.heightAnchor constraintEqualToConstant:270],
        [previewTitle.leadingAnchor constraintEqualToAnchor:metalPanel.leadingAnchor constant:16],
        [previewTitle.topAnchor constraintEqualToAnchor:metalPanel.topAnchor constant:13],
        [preview.leadingAnchor constraintEqualToAnchor:metalPanel.leadingAnchor constant:14],
        [preview.trailingAnchor constraintEqualToAnchor:metalPanel.trailingAnchor constant:-14],
        [preview.topAnchor constraintEqualToAnchor:previewTitle.bottomAnchor constant:12],
        [preview.bottomAnchor constraintEqualToAnchor:metalPanel.bottomAnchor constant:-14],

        [cards.leadingAnchor constraintEqualToAnchor:main.leadingAnchor],
        [cards.trailingAnchor constraintEqualToAnchor:main.trailingAnchor],
        [cards.topAnchor constraintEqualToAnchor:metalPanel.bottomAnchor constant:18],
        [cards.heightAnchor constraintEqualToConstant:132],
        [footer.leadingAnchor constraintEqualToAnchor:main.leadingAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:main.bottomAnchor]
    ]];

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
