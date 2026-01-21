# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**sw-chill-formal** is a Godot 4.5 project (Mobile platform) that combines 3D character interaction with a rich UI system for music management, task tracking, and text input. The project emphasizes a relaxing, chill-focused experience with Material Design UI components.

## Development Commands

This is a Godot project - there are no traditional build/test commands. Development is done through the Godot Editor:

- **Open Project**: Launch Godot Editor and open the `project.godot` file
- **Run Project**: Press F5 in Godot Editor or click the "Play" button
- **Run Current Scene**: Press F6 in Godot Editor
- **Export**: Use Project → Export in Godot Editor menu

## Architecture

### Autoload Singletons (Global Services)

The project has two critical autoload singletons defined in `project.godot`:

#### **GuiTransitions** (`addons/simple-gui-transitions/singleton.gd`)
- Manages global UI layout switching with animated transitions
- Key methods: `go_to(id, callback)`, `show(id)`, `hide(id)`
- Handles all GUI state transitions across the application

#### **AudioPlayer** (`scenes/main/audio_player/audio_player.gd`)
- Centralized audio management for BGM and SFX
- Key features:
  - Volume control with fade-in/fade-out animations
  - Play/pause state preservation across track switches
  - Dynamic BGM loading from `AudioRes` resource
  - Crossfade support between tracks
- Key methods: `play_bgm(name)`, `change_bgm(name)`, `toggle_bgm_playback()`, `set_bgm_volume()`, `crossfade_to_bgm()`
- Signals: `music_changed`, `music_finished`
- **Important**: The `is_paused` state is separate from the current track - allows switching BGM while preserving playback state

### Resource Management Pattern

#### **AudioRes** (`resource/audio_res/audio_res.gd`)
- Custom Resource class that acts as centralized audio inventory
- Contains arrays of `AudioItem` resources: `BGM` and `sound_effect`
- Supports dynamic loading: `add_bgm(name, path)` emits `bgm_added` signal
- AudioPlayer subscribes to this signal to add AudioStreamPlayer nodes dynamically

**Data Flow**:
```
AudioRes (data source) → AudioPlayer (audio engine) → MusicModule (UI controller) → MusicList (playlist view) → MusicItem (track representation)
```

### UI Module System

The UI is organized as modular, loosely-coupled components in `scenes/main/ui/`:

#### **Main UI Controller** (`ui.gd`)
- Acts as UI coordinator, manages child module signals
- Provides unified API wrapping music_module functionality
- Signal forwarding layer for global UI events

#### **MusicModule** (`scenes/main/ui/music_module/music_module.gd`)
- Core orchestrator for music playback UI
- Manages multiple playlists (MusicList instances) with dynamic switching
- Play modes: sequential (0), random (1), single loop (2)
- Key state: `current_list_index`, `is_playing`, `next_play_mode`
- Signal flow: MusicModule → AudioPlayer.change_bgm() → AudioPlayer emits music_changed → UI updates

#### **TaskModule** (`scenes/main/ui/task_module_new/task_module_new.gd`)
- Todo/task management with completion tracking
- Uses ReorderableVBox for drag-to-reorder
- Tasks separated by completion state with visual separator
- Entry animations: fade + scale with back easing (0.4s)

#### **TextModule** (`scenes/main/ui/text_module/text_module.gd`)
- Simple text input with TextEdit + Button
- Emits `text_entered(text)` signal

### Material Design UI Components

All custom components are in `scenes/main/ui/components/`:

#### **Core Components**:
- **MaterialButton**: Base button with ripple effect, multiple size presets, icon+text layout, text scrolling animation
- **MaterialCheckBox**: Custom checkbox with Material Design styling
- **MaterialToggleButton**: Multi-state button with cycle modes (forward/backward/ping-pong)
- **MaterialDialog**: Full-featured modal dialog with types (INFO, WARNING, ERROR, QUESTION), animation, callbacks
- **MaterialMenu**: Context menu with check items, separators, keyboard shortcuts
- **MaterialMenuButton**: Button with integrated dropdown menu
- **FrostedPanel**: Shader-based frosted glass effect panel (used in music module)
- **MaterialRippleMixin**: Reusable ripple effect system for buttons/checkboxes
- **MaterialSegmentedButton**: Material Design segmented selector with capsule-shaped container, blue highlight on selected item, sliding animation
- **MaterialSwitch**: Material Design toggle switch with acceleration animation and background color gradient, single size
- **MaterialTextField**: Material Design text input with pill-shaped full rounded corners, supports solid/transparent/frosted background styles
- **InnerPanel**: Inner sub-panel component with rounded corners, border, and semi-transparent background (shader-based)
- **Calendar**: Calendar widget using calendar_library plugin, supports year/month navigation and date selection
- **DatePicker**: Button that pops up a calendar picker for date selection

#### **Usage Pattern**:
- All components extend Godot primitives (Button, CheckBox, etc.) marked with `@tool` for editor preview
- Material Design applied as wrapper styling, not core framework change
- Components use composition (mixins) for shared behavior like ripple effects

### 3D Components

#### **Character** (`scenes/main/3d/character/character.gd`)
- Node3D with VRM character model support
- State management: `typing`, `happy`, `sad`, `surprised`, `saying`
- Dual AnimationTree system: `action_tree` (poses) and `emotion_tree` (emotions)
- Key methods: `set_typing()`, `set_happy()`, `set_pose_watch()`, `start_saying()`

#### **Room Components** (`scenes/main/3d/room/`)
- 3D environment props (alarm clock, dolls, etc.)

### Key Architectural Patterns

1. **Signal-Based Communication**: Almost all UI communication flows through signals. Components emit signals for user actions → parent containers listen and coordinate → root UI controller forwards critical signals upward.

2. **State Synchronization**:
   - MusicModule maintains UI state (`current_list_index`, `is_playing`, `play_mode`)
   - AudioPlayer maintains audio state (`current_bgm_name`, `is_paused`)
   - Methods like `_sync_play_status()` keep them in sync

3. **Module Independence**: UI modules (MusicModule, TaskModule, TextModule) are largely independent. New modules can be added without affecting existing ones—follow the same signal-based pattern.

4. **Separation of Concerns**:
   - AudioPlayer = playback engine (no UI logic)
   - MusicModule = UI control logic (no audio logic)
   - MaterialButton/Dialog/Menu = reusable UI primitives

5. **Scene Composition**: Rather than deeply nesting scenes, components use `instance()` to load PackedScene components dynamically (easier to debug and modify).

6. **Animation Consistency**:
   - Tasks: Tween with back easing, 0.4s
   - Dialogs: scale + alpha fade, 0.2s
   - Audio: Tween for fade in/out with configurable duration and curves

## Project Structure

```
scenes/main/
├── 3d/                      # 3D components (character, room, buildings)
├── audio_player/            # Autoload audio manager
└── ui/                      # UI modules and components
    ├── components/          # Reusable Material Design UI components
    │   ├── button/          # MaterialButton
    │   ├── calendar/        # Calendar widget
    │   ├── checkbox/        # MaterialCheckBox
    │   ├── date_picker/     # DatePicker button
    │   ├── dialog/          # MaterialDialog
    │   ├── frosted_panel/   # Shader-based frosted glass panel
    │   ├── inner_panel/     # InnerPanel (shader-based panel with rounded corners)
    │   ├── menu/            # MaterialMenu, MaterialMenuButton, MaterialMenuItem
    │   ├── segmented_button/# MaterialSegmentedButton
    │   ├── shared/          # MaterialRippleMixin, MaterialSizeConfig
    │   ├── switch/          # MaterialSwitch
    │   ├── text_field/      # MaterialTextField
    │   └── toggle_button/   # MaterialToggleButton
    ├── music_module/        # Music player UI and playlist management
    ├── task_module_new/     # Task/todo management
    └── text_module/         # Text input module

addons/                      # Third-party plugins
├── vrm/                     # VRM character support
├── Godot-MToon-Shader/      # MToon shader for VRM
├── sky_3d/                  # 3D sky rendering
├── simple-gui-transitions/  # GUI transition system (autoload)
├── SmoothScroll/            # Smooth scrolling container
├── ReorderableContainer/    # Drag-to-reorder container
├── calendar_library/        # Calendar UI component
└── markdownlabel/           # Markdown text rendering

resource/audio_res/          # Audio resource management
```

## Important Notes

- **Godot Version**: This project uses Godot 4.5 with Mobile rendering method
- **Language Convention**: All conversations, documentation, comments, and commit messages should be in Chinese (中文). The codebase contains Chinese comments throughout.
- **Enabled Plugins**: vrm, Godot-MToon-Shader, ReorderableContainer, SmoothScroll, markdownlabel, simple-gui-transitions, sky_3d
- **Color Organization**: The project uses folder colors in the editor (addons=purple, assets=yellow, scenes=green, main=pink, scripts=teal)
- **Signal Pattern**: When adding new UI features, always follow the signal-based pattern: component emits → parent listens → controller coordinates → singleton executes
- **State Preservation**: The AudioPlayer's `is_paused` state is intentionally separate from the current track to allow seamless BGM switching while maintaining play/pause state
