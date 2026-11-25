#include "MetalDevice.h"
#include "MetalComputeProbe.h"
#include "MetalRenderProbe.h"

int main()
{
    const int deviceResult = runMetalDeviceProbe();
    if (deviceResult != 0) return deviceResult;

    const int computeResult = runMetalComputeProbe();
    if (computeResult != 0) return computeResult;

    return runMetalRenderProbe();
}
