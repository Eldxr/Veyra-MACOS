#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include "MetalDevice.h"

#include <iostream>

int runMetalDeviceProbe()
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            std::cerr << "No Metal device is available on this Mac.\n";
            return 2;
        }

        id<MTLCommandQueue> queue = [device newCommandQueue];
        if (queue == nil) {
            std::cerr << "Metal device was found, but a command queue could not be created.\n";
            return 3;
        }

        const char* name = [[device name] UTF8String];
        std::cout << "Metal device: " << (name != nullptr ? name : "unknown") << '\n';
        std::cout << "Metal command queue: available\n";
        return 0;
    }
}
