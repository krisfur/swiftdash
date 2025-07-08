# SwiftDash 🐹⛷️

A Swift port of the terminal game GopherDash, built with SpriteKit for macOS and iOS.

## About

SwiftDash is an endless runner game where you control a hamster that runs right while the world scrolls left. Jump over rocks and holes to survive as long as possible and beat your high score!

## Features

- **Endless Runner Gameplay**: Keep running and jumping over obstacles
- **Progressive Difficulty**: Game speed increases gradually over time
- **High Score System**: Persistent high scores saved locally
- **Cross-Platform**: Works on both macOS and iOS
- **Simple Controls**: Space/W key or tap/click to jump
- **Game Over Cooldown**: 2-second countdown before restart

## How to Play

1. **Objective**: Run as far as possible by jumping over obstacles
2. **Controls**: 
   - **macOS**: Press `Space`, `W`, or click to jump
   - **iOS**: Tap anywhere on screen to jump
   - **Quit**: Press `Q` (macOS only)
3. **Obstacles**:
   - **Rocks** (gray): Jump over them when on the ground
   - **Holes** (black): Jump over them to avoid falling
4. **Scoring**: Distance increases every frame, speed ramps up gradually
5. **Game Over**: Hit an obstacle and wait 2 seconds to restart

## Building and Running

### Prerequisites
- Xcode 15.0 or later
- macOS 14.0 or later (for building)
- iOS 17.0 or later (for iOS target)

### Build Instructions

1. **Open the project**:
   ```bash
   open swiftdash.xcodeproj
   ```

2. **Select target**:
   - For macOS: Select "swiftdash macOS" scheme
   - For iOS: Select "swiftdash iOS" scheme

3. **Build and run**:
   - Press `Cmd+R` or click the Run button
   - For iOS, you'll need a simulator or connected device

### Project Structure

```
swiftdash/
├── swiftdash Shared/          # Shared game code
│   └── GameScene.swift        # Main game logic
├── swiftdash macOS/           # macOS-specific code
│   └── GameViewController.swift
├── swiftdash iOS/             # iOS-specific code
│   └── GameViewController.swift
└── swiftdash.xcodeproj/       # Xcode project
```

## Game Mechanics

### Physics
- **Gravity**: Constant downward acceleration
- **Jump**: Instant upward velocity when on ground
- **Ground Collision**: Player stops falling when hitting ground

### Obstacle System
- **Spawning**: Random obstacles appear ahead of player
- **Types**: Rocks (must jump over) and holes (must jump over)
- **Spacing**: Minimum gap between obstacles for fair gameplay
- **Movement**: Obstacles move left at constant speed

### Difficulty Progression
- **Speed Increase**: Frame rate accelerates gradually
- **Reset**: Speed resets to initial value on each restart
- **Balanced**: Progressive difficulty without being unfair

## High Score System

High scores are saved locally in the app's documents directory:
- **macOS**: `~/Library/Containers/[app-id]/Data/Documents/.swiftdash_highscore`
- **iOS**: App's documents directory

## Controls Reference

| Platform | Jump | Quit |
|----------|------|------|
| macOS | Space, W, or Click | Q |
| iOS | Tap | N/A |

## Development Notes

This is a Swift port of the original Go terminal game [GopherDash](https://github.com/krisfur/gopherdash). The game logic has been faithfully recreated using SpriteKit for modern Apple platforms.

### Key Differences from Terminal Version
- **Visual**: Uses SpriteKit sprites instead of emoji characters
- **Input**: Touch/mouse support in addition to keyboard
- **Platform**: Native macOS/iOS apps instead of terminal
- **Persistence**: Uses app documents directory instead of executable directory

## License

MIT © 2025 Krzysztof Furman

## Original Game

This is a port of [GopherDash](https://github.com/krisfur/gopherdash), a terminal-based endless runner written in Go using Bubble Tea. 