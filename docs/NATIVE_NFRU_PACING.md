# Native DX12 NFRU presentation (Beta)

Use Streamline DLSSG or FSR 3.1 inputs with NFRU (Beta) output. The maximum is four total outputs. Input/provider changes require restart; native multipliers update at a real-frame boundary.

The actual adapter LUID is queried for WDDM HwFlipQueueEnabled. Enabled permits Handshake initialization; disabled/query failure or unsupported initialization selects CPU fallback. SDR RGBA8/BGRA8/RGB10A2 have a shared-displayable Handshake path; other color-space/format combinations may fall back. These labels do not verify HWFQ use per present.

Presentation objects are owned by a controller thread. The producer sends GPU readiness, chronological generated/real outputs and target times. Future backlog is bounded by canceling not-yet-displayed stale presents; such cancellations mean submitted outputs need not equal displayed frames. Buffer reuse is governed by GPU fences and presentation-buffer availability. Minimized/inactive windows suspend output, and restoration resets history. The menu uses real frames only and releases cached backbuffers before resize. Exclusive fullscreen is not supported by this initial adapter; use windowed/borderless.

Submitted FPS (output/base) independently counts real frames and output submissions over a moving window, including multiplier transitions. It is not a scanout measurement. GPU timestamps are read after existing resource-reuse fences; diagnostic timings describe the last completed generated batch, not input-to-photon latency. Validate behavior yourself on your target game and display.
