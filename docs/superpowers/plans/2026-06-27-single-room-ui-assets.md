# Single Room UI Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修正当前单格监控房间里的设备素材、摆放、命中盒和鼠标悬停选中框。

**Architecture:** 保留 `RoomManager` 的九宫格房间和摄像机切房间逻辑，不改成全图可见。每个设备场景继续使用 `TextureVisual` 和 `SelectFrame`，由 `DeviceHighlighter` 在当前房间内按 `global_rect()` 命中后调用 `set_highlighted()`。

**Tech Stack:** Godot 4.6、GDScript、`.tscn` 场景、AtlasTexture `.tres` 素材裁剪。

---

### Task 1: 资源和场景对齐

**Files:**
- Modify: `assets/atlas/*.tres`
- Modify: `scenes/devices/*.tscn`
- Modify: `scenes/product.tscn`

- [ ] 确认当前素材表中已有出口、交货点、发电机、接线盒、自爆按钮、玻璃罩、加热台、加热盘、产品和猴子资源。
- [ ] 补齐产品出口设备的显示贴图和选中框。
- [ ] 调整现有设备场景里 `Visual`、`Sprite2D`、`SelectFrame` 的位置，让框和图对齐。

### Task 2: 命中盒和悬停规则

**Files:**
- Modify: `scripts/world/product_exit.gd`
- Modify: `scripts/world/heater.gd`
- Modify: `scripts/world/generator.gd`
- Modify: `scripts/world/wiring_box.gd`
- Modify: `scripts/world/self_destruct.gd`
- Modify: `scripts/world/control_panel.gd`

- [ ] 保持 `SelectFrame` 默认隐藏。
- [ ] 确保 `global_rect()` 覆盖实际可交互贴图区域。
- [ ] 确保 `DeviceHighlighter` 只在当前房间内悬停可交互物时显示白框。

### Task 3: 房间内摆放和视觉干扰

**Files:**
- Modify: `params/rooms/default_room_layout.tres`
- Modify: `scenes/main_grid.tscn`
- Modify: `scripts/ui/grid_hud.gd`

- [ ] 调整 `panel_local` 和设备位置，避免所有设备堆在房间中心。
- [ ] 保持当前单格视角，不改 `RoomManager` 的摄像机切换。
- [ ] 收敛 HUD 文本占用，避免盖住房间核心画面。

### Task 4: 验证

**Files:**
- Verify: modified `.gd` and `.tscn`

- [ ] 运行 `gdformat --check --line-length 100` 检查修改过的 GDScript。
- [ ] 运行 `gdlint` 检查修改过的 GDScript。
- [ ] 运行 `git diff --check`。
- [ ] 运行 Godot headless import。
- [ ] 运行 `main_grid.tscn` headless 启动，确认无运行时报错。
