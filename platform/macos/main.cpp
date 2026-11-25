#include "MetalDevice.h"
#include "MetalComputeProbe.h"

int main()
{
    const int deviceResult = runMetalDeviceProbe();
    if (deviceResult != 0) return deviceResult;
    return runMetalComputeProbe();
}
