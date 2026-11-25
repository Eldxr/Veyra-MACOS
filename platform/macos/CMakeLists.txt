cmake_minimum_required(VERSION 3.24)

project(VeyraMacOSMetalProbe VERSION 0.1.0 LANGUAGES CXX OBJCXX)

if(NOT APPLE)
  message(FATAL_ERROR "The Veyra macOS platform target must be configured on macOS.")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
  set(CMAKE_OSX_DEPLOYMENT_TARGET "13.0" CACHE STRING "Minimum macOS version" FORCE)
endif()

add_executable(veyra_macos_metal_probe
  main.cpp
  MetalDevice.mm
)

target_compile_options(veyra_macos_metal_probe PRIVATE
  $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
)

target_link_libraries(veyra_macos_metal_probe PRIVATE
  "-framework Foundation"
  "-framework Metal"
)

message(STATUS "Veyra macOS Metal probe: deployment target ${CMAKE_OSX_DEPLOYMENT_TARGET}")
message(STATUS "Veyra macOS Metal probe: architectures ${CMAKE_OSX_ARCHITECTURES}")
