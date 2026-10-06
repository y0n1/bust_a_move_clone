# Spec for **Bust‑A‑Move** (aka *Puzzle Bobble*)

*Based on publicly available information about the 1994 arcade puzzle game [Wikipedia – Bust A Move](https://en.wikipedia.org/wiki/Bust_a_Move).*

---

## Overview  

- **Genre**: Arcade puzzle / bubble‑shooter.  
- **Release year**: 1994 (originally as *Puzzle Bobble* in most regions; known as *Bust‑A‑Move* elsewhere).  
- **Platform**: Initially arcade, later ported to many home systems; this project targets the web via Flutter.

---

## Core Gameplay Mechanics  

| Aspect | Description |
|--------|-------------|
| **Objective per level** | Clear all bubbles present on the screen before the level‑timer expires or before a “bubble wall” reaches the bottom. |
| **Shooting mechanic** | The player controls a cannon at the lower part of the playfield that launches colored bubbles upward toward a pre‑arranged cluster of bubbles. |
| **Match rule** | When three or more bubbles of the same color touch, they pop and disappear, potentially creating chain reactions. |
| **Level progression** | Levels increase in difficulty by: <br>• tighter bubble patterns, <br>• faster spawn rates, <br>• additional obstacles (locked bubbles, moving walls). |
| **Scoring** | Points are awarded for each popped cluster; combos and rapid successive pops generate multipliers. A high‑score table tracks player performance. |
| **Lives / continues** | The game typically limits the number of lives (or attempts) per session; losing a life occurs when a bubble reaches the bottom or the timer runs out, after which the player may continue from the same level. |
| **Power‑ups / special bubbles** | • *Color‑change* bubble – lets the player select any color for the next shot.<br>• *Bomb* bubble – clears all bubbles in a radius when popped.<br>• Other specialty bubbles that aid clearance (e.g., rainbow, star). |
| **UI elements** | Start screen, pause, level selection, score display, remaining‑shot counter, and a progress bar indicating how many bubbles remain to be cleared. |

---

## Design Highlights  

- **Single‑player experience**: No multiplayer modes; the challenge is purely against the level design and timing.  
- **Retro aesthetic**: Bright, saturated colors with simple sprite animations reminiscent of 1990s arcade titles.  
- **Replay value**: Achieving high scores and completing all levels provides long‑term engagement; optional “time attack” modes can be added later.  

---

## Technical Considerations for Flutter Web Implementation  

| Area | Recommendation |
|------|----------------|
| **Game loop** | Use `Timer` or `Canvas`‑based rendering to update bubble positions each frame (≈60 fps). |
| **Physics / collision** | Simple 2‑D collision detection for bubble‑bubble and bubble‑wall hits; resolve matches by removing matched groups. |
| **Input** | Touch events map to cannon rotation and launch angle; mouse click/tap determines shot direction. |
| **Asset management** | Sprite sheets for bubbles, cannon, UI icons stored in `assets/` and declared in `pubspec.yaml`. |
| **State management** | Provider or Riverpod can hold game state (current level, score, lives) and expose it to UI widgets. |
| **Responsive layout** | Design the playfield to scale with screen size; keep aspect ratio consistent for fair gameplay across devices. |

---

## Sources  

- Overview and gameplay: **[Wikipedia – Bust A Move](https://en.wikipedia.org/wiki/Bust_a_Move)**.

---  

*This spec provides a high‑level blueprint for implementing a web‑based clone of the classic bubble‑shooter arcade game using Flutter.*
