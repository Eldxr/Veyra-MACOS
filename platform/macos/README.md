# Veyra for macOS — platform port

This directory is the start of a separate Apple-platform implementation. It is deliberately not wired into the existing root CMake project yet: the current root build returns to the Linux OBS-only target for every non-Windows platform, while the main application and renderer are Windows/Win32/D3D12-specific. Keeping the first macOS target isolated avoids changing or destabilizing the Windows release build.

## First milestone: native Metal availability

The standalone CMake project builds `veyra_macos_metal_probe`. It uses Objective-C++ only at the Metal boundary, obtains the system Metal device, creates a command queue, compiles a small Metal compute kernel at runtime, dispatches it over 256 values, and verifies the GPU results. This is a deterministic compute smoke test, not yet a video renderer: it does **not** render or present video, decode capture-card input, run image enhancement, or provide the Veyra UI.

Build on a Mac:

```sh
cmake -S platform/macos -B build/macos -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64
cmake --build build/macos --config Release
./build/macos/veyra_macos_metal_probe
```

The target has a macOS 13 deployment floor and is intended to be built for Apple Silicon (`arm64`). The actual minimum OS and supported Mac models must be confirmed against the eventual Qt and media dependency choices before a distributable app is declared.

## Porting boundaries identified from the existing source

- **UI:** retain the Qt Quick/QML product interface where practical. Replace the Windows-only application entry point and HWND child-video-window hosting with a macOS application lifecycle and a native Metal-backed surface (for example, an `NSView`/CAMetalLayer integration). Do not assume the current Windows `main.cpp` can compile unchanged.
- **GPU and presentation:** the existing enhancement/presentation implementation is D3D12/DXGI and includes NVIDIA NGX, NVAPI, DirectML, AMD AMF, and Windows-specific presentation hooks. It cannot run on Apple Silicon as-is. Build a separate Metal device/queue, texture, command-buffer, shader, synchronization, and presentation path. Preserve shared algorithm contracts only where their inputs/outputs and licensing permit.
- **Video ingest and decode:** evaluate VideoToolbox/AVFoundation for hardware decode and capture-device discovery, with CoreMedia timestamps and explicit pixel-format/color metadata. Screen capture should use ScreenCaptureKit. A capture card connected over USB/HDMI must be tested as an actual macOS capture device; HDMI input is not implied by the MacBook's HDMI output.
- **Media and audio:** keep portable media/format logic where it has no Win32 assumptions; use a macOS-compatible FFmpeg build where needed and CoreAudio/AVAudioEngine for device and clock integration. Preserve source PTS, bounded queues, explicit color handling, and reset behavior.
- **Xbox streaming:** the existing Xbox feature is explicitly unofficial/experimental. Its protocol logic is partly reusable, but current transport, credential protection, and socket code use WinHTTP, DPAPI, Winsock, and Windows shell APIs. Port those seams separately (URLSession/Network or another supported TLS transport, Keychain, and BSD sockets), then validate sign-in and a real console session. Do not copy Windows tokens or credentials into the Mac port.
- **PS5 Remote Play:** the Chiaki-derived backend may offer reusable portable protocol code, but its build, input, audio, and platform integration need a separate macOS audit and license review.
- **Enhancement providers:** Windows NGX/DLSS, DirectML, NVAPI, AMF and current vendor SDK integrations are not interchangeable with Metal. The first Mac release must not claim these backends. Candidate Apple-native paths (Metal Performance Shaders, Core ML, and custom Metal compute) require model/license review, implementation, image-quality comparison, and sustained performance tests on the target Mac.

## Next implementation sequence

1. Confirm the Metal device and compute smoke test build in CI for arm64 and run on a real Apple Silicon Mac.
2. Add a Metal texture render/presentation test with deterministic input/output and GPU-side timing; do not read pixels back in the real-time path.
3. Establish the Qt 6 macOS app shell and a Metal-backed video surface, preserving QML settings and navigation where feasible.
4. Port media decode, capture-card input, timestamps, audio, and color metadata.
5. Add an enhancement graph abstraction and the first Apple-native denoise/upscale implementation, with CPU reference tests and image-quality fixtures.
6. Port Xbox streaming and credential storage behind platform interfaces; validate real console connectivity.
7. Add packaging, signing/notarization, permissions, crash diagnostics, and full performance/stability acceptance.

## Acceptance rules

A compile-only probe is not a Veyra port. Each milestone must state exactly what is implemented, what was built, what was run, on which hardware/OS, and what remains unverified. No Windows-only feature should be shown as available on macOS until its macOS implementation has passed its own tests.
