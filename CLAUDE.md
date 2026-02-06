# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**sw-chill-formal** is a Godot 4.6 project (Mobile platform) that combines 3D character interaction with a rich UI system for music management, task tracking, AI conversation, and pomodoro timer. The project emphasizes a relaxing, chill-focused experience with Material Design UI components.

## Development Commands

This is a Godot project - there are no traditional build/test commands. Development is done through the Godot Editor:

- **Open Project**: Launch Godot Editor and open the `project.godot` file
- **Run Project**: Press F5 in Godot Editor or click the "Play" button
- **Run Current Scene**: Press F6 in Godot Editor
- **Export**: Use Project → Export in Godot Editor menu

## Architecture

### Autoload Singletons (Global Services)

The project has four critical autoload singletons defined in `project.godot`:

#### **GuiTransitions** (`addons/simple-gui-transitions/singleton.gd`)
- Manages global UI layout switching with animated transitions
- Key methods: `go_to(id, callback)`, `show(id)`, `hide(id)`
- Handles all GUI state transitions across the application

#### **AudioPlayer** (`scenes/main/audio_player/audio_player.tscn`)
- Centralized audio management for BGM and SFX
- Key features:
  - Volume control with fade-in/fade-out animations
  - Play/pause state preservation across track switches
  - Dynamic BGM loading from `AudioRes` resource
  - Crossfade support between tracks
- Key methods: `play_bgm()`, `change_bgm()`, `switch_bgm()`, `toggle_bgm_playback()`, `set_bgm_volume()`, `crossfade_to_bgm()`
- Signals: `music_changed`, `music_finished`
- **Important**: The `is_paused` state is separate from the current track - allows switching BGM while preserving playback state

#### **MusicState** (`scenes/main/audio_player/music_state.gd`)
- Centralized music state management singleton
- Acts as the single source of truth for all music-related state
- State variables: `current_track`, `is_playing`, `play_mode`, `current_playlist`, `current_track_index`
- Play modes: SEQUENTIAL (0), RANDOM (1), SINGLE_LOOP (2)
- Signals: `track_changed`, `playback_state_changed`, `play_mode_changed`, `playlist_changed`, `track_finished`
- Key methods: `set_track()`, `set_playing()`, `toggle_playback()`, `set_play_mode()`, `cycle_play_mode()`
- **Architecture**: UI and AudioPlayer both read/write state through this singleton

#### **AIService** (`scenes/main/ai_service/ai_service.tscn`)
- OpenAI-compatible API service with Server-Sent Events (SSE) streaming support
- Key features:
  - Stream-based chat completions with real-time text output
  - Multimodal support (text + images via base64 encoding)
  - Configurable API endpoint, model, max_tokens, temperature
  - Message history management for contextual conversations
  - Thread-based HTTP requests to avoid blocking main thread
- Signals: `stream_chunk_received`, `stream_completed`, `request_started`, `request_failed`, `connection_state_changed`
- Key methods: `send_message()`, `send_single_message()`, `cancel_request()`, `clear_history()`
- Components: `ai_service.gd` (main), `adapters/` (OpenAI, custom API adapters), `context_collector.gd`, `agent_executor.gd`, `tts_player.gd`

### Resource Management Pattern

#### **AudioRes** (`resource/audio_res/audio_res.gd`)
- Custom Resource class that acts as centralized audio inventory
- Contains arrays of `AudioItem` resources: `BGM` and `sound_effect`
- Supports dynamic loading: `add_bgm(name, path)` emits `bgm_added` signal
- Methods: `remove_bgm()`, `get_bgm_item_by_name()`
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
- Components: TaskItem, TaskData, LineEdit

#### **NoteModule** (`scenes/main/ui/note_module/note_module.gd`)
- Sticky note system with limit of 20 notes
- Creates draggable note windows
- API: `take_note(text)` for programmatic note creation

#### **NotebookModule** (`scenes/main/ui/notebook_module/note_book.gd`)
- Multi-page notebook with page management
- Components: PageButton (page selector), Page (content area)
- Saves page content in dictionary

#### **InputBox** (`scenes/main/ui/input_box/input_box.gd`)
- ChatGPT-style AI conversation input box
- Auto-switches between LineEdit (single-line) and TextEdit (multi-line)
- Supports image attachments (max 2)
- Smooth height animations and transitions
- Integrated with MaterialMenu, MaterialChip, MaterialSnackbar

#### **CharacterInteractor** (`scenes/main/ui/character_interactor/character_interactor.gd`)
- Simple button that emits signal after 3 clicks
- Used for character interaction triggers

#### **EnvSetter** (`scenes/main/ui/env_setter/env_setter.gd`)
- Environment time setter (daytime, afternoon, dusk, evening, sync)
- Weather setter (sunny, rainy, snowy, sync)
- Uses MaterialToggleButton for state switching

#### **PomodoroTechniqueModule** (`scenes/main/ui/pomodoro_technique_module/pomodoro_technique_module.gd`)
- Pomodoro timer implementation for focus/break management
- Configurable work duration, rest duration, and loop times
- CanvasLayer-based UI with dynamic layer management via `_request_top_layer()`
- Signals: `work_started`, `work_completed`, `work_paused`, `work_stopped`, `work_continued`
- Agent API methods:
  - `agent_start_pomodoro(work_duration, rest_duration, loop_times)` - Start timer
  - `agent_set_work_duration(minutes)` / `agent_set_rest_duration(minutes)` - Configure durations
  - `agent_toggle_pause()` / `agent_stop()` - Control playback
  - `agent_get_status()` / `agent_is_running()` / `agent_is_paused()` - Query state
- Components: `pomodoro_technique.gd` (core timer), `work.gd`, `rest.gd`, `loop.gd`

#### **DialogueBox** (`scenes/main/ui/dialogue_box/dialogue_box.gd`)
- AI conversation dialogue box with streaming text display
- Features:
  - Character-by-character streaming animation with configurable speed (`char_display_interval`)
  - Auto-adjusting height with smooth Tween animation (`min_height`, `max_height`)
  - BBCode support via RichTextLabel
  - Up to 3 action buttons with customizable text
- Signals: `dialogue_started`, `dialogue_finished`, `dialogue_stopped`, `button_pressed(button_index)`
- Key methods: `start_dialogue(text)`, `stop_dialogue()`, `skip_to_end()`, `append_text()`, `set_buttons()`, `show_module()`, `hide_module()`
- Integrates with GuiTransitions for show/hide animations

### Material Design UI Components

All custom components are in `scenes/main/ui/components/`:

#### **Core Components**:
- **MaterialButton**: Base button with ripple effect, multiple size presets, icon+text layout, text scrolling animation
- **MaterialCheckBox**: Custom checkbox with Material Design styling
- **MaterialToggleButton**: Multi-state button with cycle modes (forward/backward/ping-pong)
- **MaterialDialog**: Full-featured modal dialog with types (INFO, WARNING, ERROR, QUESTION), animation, callbacks
- **MaterialMenu**: Context menu with check items, separators, keyboard shortcuts
- **MaterialMenuButton**: Button with integrated dropdown menu
- **MaterialContextMenu**: Right-click context menu that attaches to target controls, extends MaterialMenu with automatic popup on right-click, supports `attach_to()` and `detach()` methods
- **MaterialSegmentedButton**: Material Design segmented selector with capsule-shaped container, blue highlight on selected item, sliding animation
- **MaterialSwitch**: Material Design toggle switch with acceleration animation and background color gradient, single size
- **MaterialTextField**: Material Design text input with pill-shaped full rounded corners, supports solid/transparent/frosted background styles
- **MaterialChip**: Material Design Chip component (tags/filters) with four types (ASSIST, FILTER, INPUT, SUGGESTION), three sizes (SMALL/STANDARD/LARGE), two styles (FILLED/OUTLINED), supports icons, selection state, deletion
- **MaterialFAB**: Floating Action Button with three sizes (SMALL/STANDARD/LARGE), supports Extended mode with text, customizable background and icon colors
- **MaterialSnackbar**: Bottom toast notification system with seven position options, five types (DEFAULT/INFO/SUCCESS/WARNING/ERROR), auto-dismiss with configurable duration, optional action button
- **MaterialSlider**: Material Design slider for volume/progress control, supports horizontal and vertical orientations, configurable min/max/step values
- **MaterialProgressIndicator**: Two types (LINEAR/CIRCULAR), two modes (DETERMINATE/INDETERMINATE), animated progress transitions
- **MaterialDragHandle**: Drag handle for moving parent nodes, four boundary modes (SCREEN/CUSTOM_RECT/PARENT_CONTAINER/NONE), visual feedback during drag
- **FrostedPanel**: Shader-based frosted glass effect panel (used in music module)
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
- Dual AnimationTree system: `action_tree` (poses) and `emotion_tree` (emotions)
- Pose methods: `set_typing_pose()`, `set_watch_pose()`, `set_cheer_pose()`, `set_disbelief_pose()`, `set_dodge_pose()`, `set_angry_pose()`, `set_clap_pose()`, `set_laughing_pose()`
- Emotion methods: `set_happy()`, `set_sad()`, `set_surprised()`, `set_angry()`
- Dialogue methods: `start_saying()`, `stop_saying()`

#### **Room Components** (`scenes/main/3d/room/`)
- 3D environment props (alarm clock, cup, dolls, etc.)

#### **Environment Components**
- `outdoor/` - Outdoor environment
- `rain/` - Rain effects
- `snow/` - Snow effects

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
├── ai_service/              # AI API service (autoload)
│   ├── adapters/            # AI provider adapters (OpenAI, custom)
│   ├── ai_service.gd        # Main AI service class
│   ├── context_collector.gd # Context collection for AI
│   ├── agent_executor.gd    # Agent execution logic
│   └── tts_player.gd        # Text-to-speech player
├── audio_player/            # Autoload audio manager
│   ├── audio_player.tscn    # AudioPlayer singleton
│   └── music_state.gd       # MusicState singleton
└── ui/                      # UI modules and components
	├── components/          # Reusable Material Design UI components
	│   ├── button/          # MaterialButton
	│   ├── calendar/        # Calendar widget
	│   ├── checkbox/        # MaterialCheckBox
	│   ├── chip/            # MaterialChip
	│   ├── date_picker/     # DatePicker button
	│   ├── dialog/          # MaterialDialog
	│   ├── drag_handle/     # MaterialDragHandle
	│   ├── fab/             # MaterialFAB
	│   ├── frosted_panel/   # Shader-based frosted glass panel
	│   ├── inner_panel/     # InnerPanel (shader-based panel with rounded corners)
	│   ├── menu/            # MaterialMenu, MaterialMenuButton, MaterialContextMenu, MaterialMenuItem
	│   ├── progress_indicator/ # MaterialProgressIndicator
	│   ├── segmented_button/# MaterialSegmentedButton
	│   ├── shared/          # MaterialRippleMixin, MaterialSizeConfig
	│   ├── slider/          # MaterialSlider
	│   ├── snackbar/        # MaterialSnackbar
	│   ├── switch/          # MaterialSwitch
	│   ├── text_field/      # MaterialTextField
	│   └── toggle_button/   # MaterialToggleButton
	├── character_interactor/# Character interaction trigger
	├── debug/               # Debug and test panels
	├── dialogue_box/        # AI conversation dialogue box
	├── env_setter/          # Environment time and weather setter
	├── input_box/           # ChatGPT-style AI conversation input
	├── music_module/        # Music player UI and playlist management
	├── note_module/         # Sticky note system
	├── notebook_module/     # Multi-page notebook
	├── pomodoro_technique_module/ # Pomodoro timer module
	└── task_module_new/     # Task/todo management

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

- **Godot Version**: This project uses Godot 4.6 with Mobile rendering method
- **Language Convention**: All conversations, documentation, comments, and commit messages should be in Chinese (中文). The codebase contains Chinese comments throughout.
- **Enabled Plugins**: vrm, Godot-MToon-Shader, ReorderableContainer, SmoothScroll, markdownlabel, simple-gui-transitions, sky_3d
- **Color Organization**: The project uses folder colors in the editor (addons=purple, assets=yellow, scenes=green, main=pink, scripts=teal)
- **Signal Pattern**: When adding new UI features, always follow the signal-based pattern: component emits → parent listens → controller coordinates → singleton executes
- **State Preservation**: The AudioPlayer's `is_paused` state is intentionally separate from the current track to allow seamless BGM switching while maintaining play/pause state
