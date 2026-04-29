# Shadow’s Revenge  
### A Godot 4 Action‑Adventure Prototype by South Side Studios  
Play it on Itch.io: https://south-side-studios.itch.io/shadows-revenge

Shadow’s Revenge is a Godot 4 project featuring a fully‑implemented UI framework, player systems, audio design, and a custom shadow‑world mechanic. This repository contains the complete source code for the prototype, including menus, settings, in‑game UI, audio, and player logic.

---

#  Features

##  Main Menu System
A complete, polished main menu built with Godot 4’s UI system.

### Includes:
- **Start Game**
- **Options Panel**
  - Resolution selector (1280×720 → 4K)
  - Fullscreen toggle
  - Settings saved to `user://settings.cfg`
- **Multi‑Page Credits**
  - Page 1 / Page 2 navigation
  - Next / Previous / Close buttons
- **Quit Game**
- **UI SFX**
  - Hover sound: `Minimalist4.wav`
  - Click sound: `Minimalist10.wav`
  - All buttons use a shared `AudioStreamPlayer3D`

---

#  In‑Game Pause Menu
A fully functional pause menu integrated into the Player scene.

### Features:
- Opens/closes with **Esc**
- **Resume**
- **Options** (same panel as Main Menu)
- **Main Menu**
- **Quit**
- Works while the game is paused (`pause_mode = process`)
- UI SFX on all buttons
- Clean show/hide transitions

---

#  Options System (Shared Between Menus)
A unified settings system used by both Main Menu and Pause Menu.

### Includes:
- Resolution dropdown
- Fullscreen toggle
- Automatic save/load using `ConfigFile`
- Applies settings immediately
- Works in both menus without duplication

---

# 🔊 UI Audio System
A simple, reusable audio system for all UI interactions.

### Implementation:
- One `AudioStreamPlayer3D` under the camera
- Hover + click sounds dynamically assigned
- Reusable helper function:
  - `add_sfx_to_button(button)`
- Works for:
  - Main Menu buttons  
  - Credits buttons  
  - OptionsPanel buttons  
  - PauseMenu buttons  

---

# Player System
The Player scene includes:

### Components:
- `AnimatedSprite3D`
- `CollisionShape3D`
- `ShadowCheck` raycast
- `PlayerCamera`
- `Hitbox`
- `Ability` node
- Full UI layer:
  - PlayerBubble (dialogue)
  - NarratorBox
  - Proceed prompt
  - Letterbox cinematic bars
  - PauseMenu
  - OptionsPanel

---

#  Shadow World Mechanic
A custom traversal system allowing the player to move between the light world and the shadow world.

### Features:
- Floor/ceiling shadow detection
- Fall‑through and rise‑up mechanics
- ShadowCheck raycast system
- Groups:
  - `ShadowFloor`
  - `ShadowCeiling`
  - `ShadowFloorExit`
  - `ShadowCeilingExit`
- Toggleable via `GivePowers` event

---

# 🗨️ Dialogue & UI Elements
### PlayerBubble
- Displays player dialogue
- Clean panel + label layout

### NarratorBox
- Displays narrator text
- Independent UI layer

### Proceed Prompt
- Appears when advancing dialogue

### Letterbox System
- Top and bottom bars for cutscenes
- Fade overlay for transitions

---

#  Audio
All UI audio stored in:

res://Assets/SFX/UI/
Code


Used files:
- `Minimalist4.wav` — hover
- `Minimalist10.wav` — click

---

#  Project Structure (Simplified)

MainMenu

├── UI

│    ├── MarginContainer

│    ├── Title1

│    ├── Title2

│    ├── Credits

│    └── OptionsPanel

└── WorldRoot

└── Camera3D

└── AudioStreamPlayer3D


Player

└── UI

├── PlayerBubble

├── NarratorBox

├── Proceed

├── Letterbox

├── PauseMenu

└── OptionsPanel

---

#  How to Run
1. Clone the repository  
2. Open the project in **Godot 4.x**  
3. Run the Main Menu scene or the full game scene  
4. Press **Esc** in‑game to open the Pause Menu  

---

#  License
MIT License

---

#  Developer
**Jason Marty**  
South Side Studios  
