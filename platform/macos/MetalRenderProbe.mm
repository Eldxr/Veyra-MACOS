#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "MetalRenderProbe.h"

#include <cmath>
#include <cstdint>
#include <iostream>

int runMetalRenderProbe()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            std::cerr << "Metal render test: no Metal device.\n";
            return 2;
        }

        static NSString * const shaderSource = @
            "#include <metal_stdlib>\n"
            "using namespace metal;\n"
            "struct VertexOut { float4 position [[position]]; };\n"
            "vertex VertexOut veyraVertex(uint id [[vertex_id]]) {\n"
            "  constexpr float2 p[3] = { float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0) };\n"
            "  VertexOut out; out.position = float4(p[id], 0.0, 1.0); return out;\n"
            "}\n"
            "fragment float4 veyraFragment() { return float4(0.2, 0.4, 0.8, 1.0); }\n";

        NSError *error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:shaderSource options:nil error:&error];
        if (library == nil) {
            std::cerr << "Metal render test: shader compilation failed: "
                      << (error.localizedDescription.UTF8String ?: "unknown error") << '\n';
            return 3;
        }

        MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"veyraVertex"];
        pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"veyraFragment"];
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

        id<MTLRenderPipelineState> pipeline =
            [device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        if (pipeline == nil) {
            std::cerr << "Metal render test: pipeline creation failed: "
                      << (error.localizedDescription.UTF8String ?: "unknown error") << '\n';
            return 4;
        }

        constexpr NSUInteger width = 64;
        constexpr NSUInteger height = 64;
        MTLTextureDescriptor *textureDescriptor =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                               width:width height:height mipmapped:NO];
        textureDescriptor.usage = MTLTextureUsageRenderTarget;
        textureDescriptor.storageMode = MTLStorageModeShared;
        id<MTLTexture> texture = [device newTextureWithDescriptor:textureDescriptor];
        id<MTLCommandQueue> queue = [device newCommandQueue];
        if (texture == nil || queue == nil) {
            std::cerr << "Metal render test: could not allocate render target or command queue.\n";
            return 5;
        }

        MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = texture;
        pass.colorAttachments[0].loadAction = MTLLoadActionClear;
        pass.colorAttachments[0].storeAction = MTLStoreActionStore;
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);

        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
        [encoder setRenderPipelineState:pipeline];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];

        if (command.status != MTLCommandBufferStatusCompleted) {
            std::cerr << "Metal render test: command buffer did not complete.\n";
            return 6;
        }

        uint8_t pixel[4] = {};
        [texture getBytes:pixel bytesPerRow:sizeof(pixel)
                   fromRegion:MTLRegionMake2D(width / 2, height / 2, 1, 1) mipmapLevel:0];
        // BGRA8 target for the fragment colour (R=.2, G=.4, B=.8, A=1).
        const bool valid = std::abs(static_cast<int>(pixel[0]) - 204) <= 2 &&
                           std::abs(static_cast<int>(pixel[1]) - 102) <= 2 &&
                           std::abs(static_cast<int>(pixel[2]) - 51) <= 2 &&
                           pixel[3] >= 253;
        if (!valid) {
            std::cerr << "Metal render test: unexpected centre pixel BGRA="
                      << static_cast<int>(pixel[0]) << ','
                      << static_cast<int>(pixel[1]) << ','
                      << static_cast<int>(pixel[2]) << ','
                      << static_cast<int>(pixel[3]) << '\n';
            return 7;
        }

        std::cout << "Metal render test: PASS (64x64 off-screen frame rendered on "
                  << device.name.UTF8String << ").\n";
        return 0;
    }
}
