#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "MetalComputeProbe.h"

#include <cstdint>
#include <iostream>
#include <vector>

int runMetalComputeProbe()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            std::cerr << "Metal compute test: no Metal device.\n";
            return 2;
        }

        static NSString * const source = @
            "#include <metal_stdlib>\n"
            "using namespace metal;\n"
            "kernel void add_one(device const uint *input [[buffer(0)]],\n"
            "                    device uint *output [[buffer(1)]],\n"
            "                    uint index [[thread_position_in_grid]]) {\n"
            "  output[index] = input[index] + 1u;\n"
            "}\n";

        NSError *error = nil;
        id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
        if (library == nil) {
            std::cerr << "Metal compute test: shader compilation failed: "
                      << (error.localizedDescription.UTF8String ?: "unknown error") << '\n';
            return 3;
        }

        id<MTLFunction> function = [library newFunctionWithName:@"add_one"];
        id<MTLComputePipelineState> pipeline =
            [device newComputePipelineStateWithFunction:function error:&error];
        if (pipeline == nil) {
            std::cerr << "Metal compute test: pipeline creation failed.\n";
            return 4;
        }

        constexpr NSUInteger count = 256;
        std::vector<uint32_t> input(count);
        for (NSUInteger i = 0; i < count; ++i) input[i] = static_cast<uint32_t>(i);

        id<MTLBuffer> inputBuffer =
            [device newBufferWithBytes:input.data() length:count * sizeof(uint32_t)
                               options:MTLResourceStorageModeShared];
        id<MTLBuffer> outputBuffer =
            [device newBufferWithLength:count * sizeof(uint32_t)
                                options:MTLResourceStorageModeShared];
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> command = [queue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
        [encoder setComputePipelineState:pipeline];
        [encoder setBuffer:inputBuffer offset:0 atIndex:0];
        [encoder setBuffer:outputBuffer offset:0 atIndex:1];

        const NSUInteger width = pipeline.threadExecutionWidth;
        [encoder dispatchThreads:MTLSizeMake(count, 1, 1)
           threadsPerThreadgroup:MTLSizeMake(width, 1, 1)];
        [encoder endEncoding];
        [command commit];
        [command waitUntilCompleted];

        if (command.status != MTLCommandBufferStatusCompleted) {
            std::cerr << "Metal compute test: command buffer did not complete.\n";
            return 5;
        }

        const auto *output = static_cast<const uint32_t *>(outputBuffer.contents);
        for (NSUInteger i = 0; i < count; ++i) {
            if (output[i] != input[i] + 1u) {
                std::cerr << "Metal compute test: incorrect result at element " << i << ".\n";
                return 6;
            }
        }

        std::cout << "Metal compute test: PASS (256 values processed on "
                  << device.name.UTF8String << ").\n";
        return 0;
    }
}
