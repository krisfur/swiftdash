//
//  GameScene.swift
//  swiftdash Shared
//
//  Created by Kris Furman on 08/07/2025.
//

import SpriteKit
import Foundation

// MARK: - Game Constants
struct GameConstants {
    static let targetFrameRate: TimeInterval = 1.0/60.0 // 60 FPS
    static let speedMultiplierIncrease: Double = 1.001 // Increase movement speed over time
    static let cooldownSeconds: TimeInterval = 2.0
    static let gravity: CGFloat = -1.0 // Gravity pulls down
    static let jumpVelocity: CGFloat = 16.0 // Higher jump
    static let minGapCells: Int = 150 // Much larger minimum gap for fairness
    static let obstacleSpawnProbability: Double = 0.12
    static let rockProbability: Double = 0.5
    static let baseObstacleSpeed: CGFloat = 5.0 // Base movement speed
}

// MARK: - Layout Configuration
struct LayoutConfig {
    let playerXPercent: CGFloat = 0.15 // 15% from left edge
    let groundHeightPercent: CGFloat = 0.15 // 15% from bottom
    let minGroundHeight: CGFloat = 60 // Minimum ground height
    let maxGroundHeight: CGFloat = 150 // Maximum ground height
    let playerSize: CGSize = CGSize(width: 30, height: 30)
    let groundThickness: CGFloat = 20
    
    // UI positioning
    let distanceLabelPosition: CGPoint = CGPoint(x: 0.1, y: 0.9) // Screen percentage
    let highScoreLabelPosition: CGPoint = CGPoint(x: 0.1, y: 0.85)
    let gameOverLabelPosition: CGPoint = CGPoint(x: 0.5, y: 0.6)
    let restartLabelPosition: CGPoint = CGPoint(x: 0.5, y: 0.45)
    let cooldownLabelPosition: CGPoint = CGPoint(x: 0.5, y: 0.35)
    
    // Font size as percentage of smaller screen dimension
    let distanceFontSize: CGFloat = 0.04
    let highScoreFontSize: CGFloat = 0.03
    let gameOverFontSize: CGFloat = 0.08
    let restartFontSize: CGFloat = 0.04
    let cooldownFontSize: CGFloat = 0.035
    
    // Safe margins - adaptive for iOS vs macOS
    #if os(iOS)
    let topMargin: CGFloat = 60 // More space for iOS status bar/notch
    let bottomMargin: CGFloat = 40 // More space for iOS home indicator
    let sideMargin: CGFloat = 20
    #else
    let topMargin: CGFloat = 20
    let bottomMargin: CGFloat = 20  
    let sideMargin: CGFloat = 20
    #endif
}

// MARK: - Game Objects
enum ObstacleType {
    case hole
    case rock
}

struct Obstacle {
    var x: CGFloat
    var type: ObstacleType
}

// MARK: - Game State
enum GameState {
    case mainMenu
    case settings
    case playing
    case gameOver
    case cooldown
}

class GameScene: SKScene {
    
    // MARK: - Layout
    private let layout = LayoutConfig()
    
    // MARK: - Game State
    private var gameState: GameState = .mainMenu
    private var distance: Int = 0
    private var highScore: Int = 0
    private var lastUpdateTime: TimeInterval = 0
    private var speedMultiplier: Double = 1.0 // Tracks current game speed
    
    // MARK: - Player
    private var player: SKSpriteNode!
    private var playerVelocityY: CGFloat = 0
    private var playerY: CGFloat = 0
    
    // MARK: - Calculated Layout Values
    private var currentLayout: (
        groundY: CGFloat,
        playerX: CGFloat,
        playerGroundY: CGFloat,
        fontSize: CGFloat
    ) = (0, 0, 0, 0)
    
    // MARK: - Obstacles
    private var obstacles: [Obstacle] = []
    private var obstacleNodes: [SKSpriteNode] = []
    
    // MARK: - UI Elements
    private var distanceLabel: SKLabelNode!
    private var highScoreLabel: SKLabelNode!
    private var gameOverLabel: SKLabelNode!
    private var restartLabel: SKLabelNode!
    private var cooldownLabel: SKLabelNode!
    
    // MARK: - Menu UI Elements
    private var titleLabel: SKLabelNode!
    private var playButton: SKLabelNode!
    private var settingsButton: SKLabelNode!
    private var backButton: SKLabelNode!
    private var gameMenuButton: SKLabelNode! // Back to menu button during game
    private var gameMenuButtonBackground: SKSpriteNode! // Background for menu button
    private var volumeLabel: SKLabelNode!
    private var volumeSliderBackground: SKSpriteNode!
    private var volumeSliderKnob: SKSpriteNode!
    private var resetHighScoreButton: SKLabelNode!
    private var confirmResetLabel: SKLabelNode!
    private var confirmYesButton: SKLabelNode!
    private var confirmNoButton: SKLabelNode!
    
    // MARK: - Game World
    private var ground: SKSpriteNode!
    private var worldNode: SKNode!
    
    // MARK: - Cooldown
    private var cooldownEndTime: TimeInterval = 0
    
    // MARK: - Settings
    private var volume: Float = 1.0 // 0.0 to 1.0
    private var showingResetConfirmation: Bool = false
    
    // MARK: - Scene Setup
    class func newGameScene() -> GameScene {
        // Create scene programmatically instead of loading from .sks
        let scene = GameScene(size: CGSize(width: 800, height: 600))
        scene.scaleMode = .aspectFill
        scene.backgroundColor = SKColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0) // Sky blue background
        return scene
    }
    
    override func didMove(to view: SKView) {
        setupScene()
        loadHighScore()
        loadSettings()
        
        #if os(iOS)
        // Add left edge swipe gesture for going back to menu
        let leftEdgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleLeftEdgeSwipe(_:)))
        leftEdgeGesture.edges = .left
        view.addGestureRecognizer(leftEdgeGesture)
        #endif
        
        showMainMenu()
    }
    
    private func setupScene() {
        // Calculate initial layout
        updateLayout()
        
        // Setup world container
        worldNode = SKNode()
        addChild(worldNode)
        
        // Setup UI (includes both game and menu elements)
        setupUI()
    }
    
    private func getSafeMargins() -> (top: CGFloat, bottom: CGFloat, side: CGFloat) {
        var topMargin = layout.topMargin
        var bottomMargin = layout.bottomMargin
        var sideMargin = layout.sideMargin
        
        #if os(iOS)
        // Use actual safe area if available
        if let view = self.view {
            if #available(iOS 11.0, *) {
                topMargin = max(topMargin, view.safeAreaInsets.top)
                bottomMargin = max(bottomMargin, view.safeAreaInsets.bottom)
                sideMargin = max(sideMargin, max(view.safeAreaInsets.left, view.safeAreaInsets.right))
            }
        }
        #endif
        
        return (top: topMargin, bottom: bottomMargin, side: sideMargin)
    }
    
    private func updateLayout() {
        // Calculate safe screen dimensions with platform-specific safe areas
        let margins = getSafeMargins()
        let safeWidth = max(size.width - margins.side * 2, 200)
        let safeHeight = max(size.height - margins.top - margins.bottom, 200)
        
        // Calculate ground position with constraints
        let groundHeightFromBottom = size.height * layout.groundHeightPercent
        let constrainedGroundHeight = max(layout.minGroundHeight, 
                                        min(layout.maxGroundHeight, groundHeightFromBottom))
        let groundY = margins.bottom + constrainedGroundHeight
        
        // Calculate player position (slightly into ground so it can collide with holes)
        let playerX = margins.side + safeWidth * layout.playerXPercent
        let playerGroundY = groundY + layout.groundThickness / 2 + layout.playerSize.height / 2 - 8
        
        // Calculate responsive font size
        let baseFontSize = min(safeWidth, safeHeight)
        
        currentLayout = (
            groundY: groundY,
            playerX: playerX, 
            playerGroundY: playerGroundY,
            fontSize: baseFontSize
        )
    }
    
    private func setupGround() {
        ground = SKSpriteNode(color: .brown, size: CGSize(width: size.width * 2, height: layout.groundThickness))
        ground.position = CGPoint(x: size.width / 2, y: currentLayout.groundY)
        ground.zPosition = 1
        addChild(ground)
    }
    
    private func setupPlayer() {
        // Create a simple hamster sprite (placeholder)
        player = SKSpriteNode(color: .orange, size: layout.playerSize)
        player.position = CGPoint(x: currentLayout.playerX, y: currentLayout.playerGroundY)
        player.zPosition = 10
        addChild(player)
        
        // Add a simple face to make it look more like a hamster
        let eye1 = SKSpriteNode(color: .black, size: CGSize(width: 4, height: 4))
        eye1.position = CGPoint(x: -8, y: 8)
        player.addChild(eye1)
        
        let eye2 = SKSpriteNode(color: .black, size: CGSize(width: 4, height: 4))
        eye2.position = CGPoint(x: 8, y: 8)
        player.addChild(eye2)
        
        playerY = player.position.y
    }
    
    private func setupUI() {
        // Get current safe margins
        let margins = getSafeMargins()
        
        // Distance label
        distanceLabel = SKLabelNode(fontNamed: "Arial-Bold")
        distanceLabel.fontSize = currentLayout.fontSize * layout.distanceFontSize
        distanceLabel.fontColor = .white
        distanceLabel.horizontalAlignmentMode = .left
        distanceLabel.verticalAlignmentMode = .top
        distanceLabel.position = CGPoint(
            x: size.width * layout.distanceLabelPosition.x + margins.side,
            y: size.height * layout.distanceLabelPosition.y - margins.top
        )
        distanceLabel.zPosition = 100
        addChild(distanceLabel)
        
        // High score label
        highScoreLabel = SKLabelNode(fontNamed: "Arial")
        highScoreLabel.fontSize = currentLayout.fontSize * layout.highScoreFontSize
        highScoreLabel.fontColor = .yellow
        highScoreLabel.horizontalAlignmentMode = .left
        highScoreLabel.verticalAlignmentMode = .top
        highScoreLabel.position = CGPoint(
            x: size.width * layout.highScoreLabelPosition.x + margins.side,
            y: size.height * layout.highScoreLabelPosition.y - margins.top
        )
        highScoreLabel.zPosition = 100
        addChild(highScoreLabel)
        
        // Game over label
        gameOverLabel = SKLabelNode(fontNamed: "Arial-Bold")
        gameOverLabel.fontSize = currentLayout.fontSize * layout.gameOverFontSize
        gameOverLabel.fontColor = .red
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.horizontalAlignmentMode = .center
        gameOverLabel.verticalAlignmentMode = .center
        gameOverLabel.position = CGPoint(
            x: size.width * layout.gameOverLabelPosition.x,
            y: size.height * layout.gameOverLabelPosition.y
        )
        gameOverLabel.zPosition = 100
        gameOverLabel.isHidden = true
        addChild(gameOverLabel)
        
        // Restart label
        restartLabel = SKLabelNode(fontNamed: "Arial")
        restartLabel.fontSize = currentLayout.fontSize * layout.restartFontSize
        restartLabel.fontColor = .white
        restartLabel.text = "Jump to restart"
        restartLabel.horizontalAlignmentMode = .center
        restartLabel.verticalAlignmentMode = .center
        restartLabel.position = CGPoint(
            x: size.width * layout.restartLabelPosition.x,
            y: size.height * layout.restartLabelPosition.y
        )
        restartLabel.zPosition = 100
        restartLabel.isHidden = true
        addChild(restartLabel)
        
        // Cooldown label
        cooldownLabel = SKLabelNode(fontNamed: "Arial")
        cooldownLabel.fontSize = currentLayout.fontSize * layout.cooldownFontSize
        cooldownLabel.fontColor = .orange
        cooldownLabel.horizontalAlignmentMode = .center
        cooldownLabel.verticalAlignmentMode = .center
        cooldownLabel.position = CGPoint(
            x: size.width * layout.cooldownLabelPosition.x,
            y: size.height * layout.cooldownLabelPosition.y
        )
        cooldownLabel.zPosition = 100
        cooldownLabel.isHidden = true
        addChild(cooldownLabel)
        
        // MARK: - Menu UI Setup
        
        // Title label
        titleLabel = SKLabelNode(fontNamed: "Arial-Bold")
        titleLabel.fontSize = currentLayout.fontSize * 0.12
        titleLabel.fontColor = .white
        titleLabel.text = "SwiftDash"
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.7)
        titleLabel.zPosition = 100
        addChild(titleLabel)
        
        // Play button
        playButton = SKLabelNode(fontNamed: "Arial-Bold")
        playButton.fontSize = currentLayout.fontSize * 0.06
        playButton.fontColor = .green
        playButton.text = "PLAY"
        playButton.horizontalAlignmentMode = .center
        playButton.verticalAlignmentMode = .center
        playButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        playButton.zPosition = 100
        playButton.name = "playButton"
        addChild(playButton)
        
        // Settings button
        settingsButton = SKLabelNode(fontNamed: "Arial-Bold")
        settingsButton.fontSize = currentLayout.fontSize * 0.05
        settingsButton.fontColor = .cyan
        settingsButton.text = "SETTINGS"
        settingsButton.horizontalAlignmentMode = .center
        settingsButton.verticalAlignmentMode = .center
        settingsButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.35)
        settingsButton.zPosition = 100
        settingsButton.name = "settingsButton"
        addChild(settingsButton)
        
        // Back button
        backButton = SKLabelNode(fontNamed: "Arial-Bold")
        backButton.fontSize = currentLayout.fontSize * 0.05
        backButton.fontColor = .white
        backButton.text = "BACK"
        backButton.horizontalAlignmentMode = .center
        backButton.verticalAlignmentMode = .center
        backButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.25) // Higher position for better visibility
        backButton.zPosition = 100
        backButton.name = "backButton"
        backButton.isHidden = true
        addChild(backButton)
        
        // Game menu button (for returning to menu during gameplay)
        gameMenuButton = SKLabelNode(fontNamed: "Arial-Bold")
        gameMenuButton.fontSize = currentLayout.fontSize * layout.distanceFontSize // Same size as distance label
        gameMenuButton.fontColor = .white
        gameMenuButton.text = "Menu"
        gameMenuButton.horizontalAlignmentMode = .right
        gameMenuButton.verticalAlignmentMode = .top
        // Position to the left of the distance label at same height
        let menuButtonX = size.width * layout.distanceLabelPosition.x + margins.side - 20 // 20px to the left of score
        let menuButtonY = size.height * layout.distanceLabelPosition.y - margins.top
        gameMenuButton.position = CGPoint(x: menuButtonX, y: menuButtonY)
        gameMenuButton.zPosition = 100
        gameMenuButton.name = "gameMenuButton"
        gameMenuButton.isHidden = true
        addChild(gameMenuButton)
        
        // Add subtle background for menu button
        gameMenuButtonBackground = SKSpriteNode(color: .black, size: CGSize(width: 60, height: 25))
        gameMenuButtonBackground.alpha = 0.3
        gameMenuButtonBackground.position = CGPoint(x: menuButtonX - 30, y: menuButtonY - 12)
        gameMenuButtonBackground.zPosition = 99
        gameMenuButtonBackground.name = "gameMenuButtonBackground"
        gameMenuButtonBackground.isHidden = true
        addChild(gameMenuButtonBackground)
        
        // Volume label
        volumeLabel = SKLabelNode(fontNamed: "Arial-Bold")
        volumeLabel.fontSize = currentLayout.fontSize * 0.04
        volumeLabel.fontColor = .white
        volumeLabel.text = "Volume: \(Int(volume * 100))%"
        volumeLabel.horizontalAlignmentMode = .center
        volumeLabel.verticalAlignmentMode = .center
        volumeLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.6) // Moved down from 0.65 to 0.6
        volumeLabel.zPosition = 100
        volumeLabel.isHidden = true
        addChild(volumeLabel)
        
        // Volume slider background
        volumeSliderBackground = SKSpriteNode(color: .gray, size: CGSize(width: 200, height: 10))
        volumeSliderBackground.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5) // Moved down from 0.55 to 0.5
        volumeSliderBackground.zPosition = 100
        volumeSliderBackground.name = "volumeSlider"
        volumeSliderBackground.isHidden = true
        addChild(volumeSliderBackground)
        
        // Volume slider knob
        volumeSliderKnob = SKSpriteNode(color: .white, size: CGSize(width: 20, height: 20))
        volumeSliderKnob.position = CGPoint(
            x: volumeSliderBackground.position.x - 90 + CGFloat(volume) * 180,
            y: volumeSliderBackground.position.y
        )
        volumeSliderKnob.zPosition = 101
        volumeSliderKnob.name = "volumeKnob"
        volumeSliderKnob.isHidden = true
        addChild(volumeSliderKnob)
        
        // Reset high score button
        resetHighScoreButton = SKLabelNode(fontNamed: "Arial-Bold")
        resetHighScoreButton.fontSize = currentLayout.fontSize * 0.04
        resetHighScoreButton.fontColor = .red
        resetHighScoreButton.text = "Reset High Score"
        resetHighScoreButton.horizontalAlignmentMode = .center
        resetHighScoreButton.verticalAlignmentMode = .center
        resetHighScoreButton.position = CGPoint(x: size.width * 0.5, y: size.height * 0.4)
        resetHighScoreButton.zPosition = 100
        resetHighScoreButton.name = "resetHighScoreButton"
        resetHighScoreButton.isHidden = true
        addChild(resetHighScoreButton)
        
        // Confirmation popup elements
        confirmResetLabel = SKLabelNode(fontNamed: "Arial-Bold")
        confirmResetLabel.fontSize = currentLayout.fontSize * 0.04
        confirmResetLabel.fontColor = .white
        confirmResetLabel.text = "Reset high score? This cannot be undone!"
        confirmResetLabel.horizontalAlignmentMode = .center
        confirmResetLabel.verticalAlignmentMode = .center
        confirmResetLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
        confirmResetLabel.zPosition = 110
        confirmResetLabel.isHidden = true
        addChild(confirmResetLabel)
        
        confirmYesButton = SKLabelNode(fontNamed: "Arial-Bold")
        confirmYesButton.fontSize = currentLayout.fontSize * 0.05
        confirmYesButton.fontColor = .red
        confirmYesButton.text = "YES"
        confirmYesButton.horizontalAlignmentMode = .center
        confirmYesButton.verticalAlignmentMode = .center
        confirmYesButton.position = CGPoint(x: size.width * 0.4, y: size.height * 0.4)
        confirmYesButton.zPosition = 110
        confirmYesButton.name = "confirmYes"
        confirmYesButton.isHidden = true
        addChild(confirmYesButton)
        
        confirmNoButton = SKLabelNode(fontNamed: "Arial-Bold")
        confirmNoButton.fontSize = currentLayout.fontSize * 0.05
        confirmNoButton.fontColor = .green
        confirmNoButton.text = "NO"
        confirmNoButton.horizontalAlignmentMode = .center
        confirmNoButton.verticalAlignmentMode = .center
        confirmNoButton.position = CGPoint(x: size.width * 0.6, y: size.height * 0.4)
        confirmNoButton.zPosition = 110
        confirmNoButton.name = "confirmNo"
        confirmNoButton.isHidden = true
        addChild(confirmNoButton)
        
        updateUI()
    }
    
    // Handle window resize
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // Recalculate layout for new screen size
        updateLayout()
        
        // Update ground
        if let ground = ground {
            ground.size = CGSize(width: size.width * 2, height: layout.groundThickness)
            ground.position = CGPoint(x: size.width / 2, y: currentLayout.groundY)
        }
        
        // Update player position (preserve relative Y position above ground)
        if let player = player {
            let wasAboveGround = playerY > currentLayout.playerGroundY
            let heightAboveGround = max(0, playerY - currentLayout.playerGroundY)
            
            player.position.x = currentLayout.playerX
            
            // If player was on ground, keep on ground; if jumping, maintain relative height
            if wasAboveGround {
                playerY = currentLayout.playerGroundY + heightAboveGround
            } else {
                playerY = currentLayout.playerGroundY
            }
            player.position.y = playerY
        }
        
        // Update all UI elements with new layout
        updateAllUIPositions()
        
        // Update existing obstacle positions to match new screen proportions
        updateObstaclePositions()
    }
    
    private func updateAllUIPositions() {
        let margins = getSafeMargins()
        
        // Update distance label
        if let label = distanceLabel {
            label.fontSize = currentLayout.fontSize * layout.distanceFontSize
            label.position = CGPoint(
                x: size.width * layout.distanceLabelPosition.x + margins.side,
                y: size.height * layout.distanceLabelPosition.y - margins.top
            )
        }
        
        // Update high score label  
        if let label = highScoreLabel {
            label.fontSize = currentLayout.fontSize * layout.highScoreFontSize
            label.position = CGPoint(
                x: size.width * layout.highScoreLabelPosition.x + margins.side,
                y: size.height * layout.highScoreLabelPosition.y - margins.top
            )
        }
        
        // Update game over label
        if let label = gameOverLabel {
            label.fontSize = currentLayout.fontSize * layout.gameOverFontSize
            label.position = CGPoint(
                x: size.width * layout.gameOverLabelPosition.x,
                y: size.height * layout.gameOverLabelPosition.y
            )
        }
        
        // Update restart label
        if let label = restartLabel {
            label.fontSize = currentLayout.fontSize * layout.restartFontSize
            label.position = CGPoint(
                x: size.width * layout.restartLabelPosition.x,
                y: size.height * layout.restartLabelPosition.y
            )
        }
        
        // Update cooldown label
        if let label = cooldownLabel {
            label.fontSize = currentLayout.fontSize * layout.cooldownFontSize
            label.position = CGPoint(
                x: size.width * layout.cooldownLabelPosition.x,
                y: size.height * layout.cooldownLabelPosition.y
            )
        }
        
        // Update game menu button
        if let button = gameMenuButton {
            button.fontSize = currentLayout.fontSize * layout.distanceFontSize
            // Position to the left of the distance label at same height
            let menuButtonX = size.width * layout.distanceLabelPosition.x + margins.side - 20 // 20px to the left of score
            let menuButtonY = size.height * layout.distanceLabelPosition.y - margins.top
            button.position = CGPoint(x: menuButtonX, y: menuButtonY)
            
            // Update background position
            if let background = gameMenuButtonBackground {
                background.position = CGPoint(x: menuButtonX - 30, y: menuButtonY - 12)
            }
        }
    }
    
    private func updateObstaclePositions() {
        // Update visual obstacle nodes to match new ground position
        for i in 0..<min(obstacles.count, obstacleNodes.count) {
            let obstacle = obstacles[i]
            let node = obstacleNodes[i]
            
            // Update Y position based on new ground level
            let newY = obstacle.type == .rock ? currentLayout.groundY + layout.groundThickness/2 + 15 : currentLayout.groundY
            node.position.y = newY
        }
    }
    
    // MARK: - Menu System
    private func showMainMenu() {
        gameState = .mainMenu
        hideAllMenuElements()
        
        titleLabel.isHidden = false
        playButton.isHidden = false
        settingsButton.isHidden = false
        
        // Hide game elements
        hideGameElements()
        
        // Clean up obstacles when returning to menu
        cleanupGameWorld()
    }
    
    private func showSettings() {
        gameState = .settings
        hideAllMenuElements()
        
        titleLabel.isHidden = false
        volumeLabel.isHidden = false
        volumeSliderBackground.isHidden = false
        volumeSliderKnob.isHidden = false
        resetHighScoreButton.isHidden = false
        backButton.isHidden = false
        
        updateVolumeDisplay()
    }
    
    private func hideAllMenuElements() {
        titleLabel.isHidden = true
        playButton.isHidden = true
        settingsButton.isHidden = true
        backButton.isHidden = true
        gameMenuButton.isHidden = true
        gameMenuButtonBackground.isHidden = true
        volumeLabel.isHidden = true
        volumeSliderBackground.isHidden = true
        volumeSliderKnob.isHidden = true
        resetHighScoreButton.isHidden = true
        confirmResetLabel.isHidden = true
        confirmYesButton.isHidden = true
        confirmNoButton.isHidden = true
        showingResetConfirmation = false
    }
    
    private func hideGameElements() {
        distanceLabel.isHidden = true
        highScoreLabel.isHidden = true
        gameOverLabel.isHidden = true
        restartLabel.isHidden = true
        cooldownLabel.isHidden = true
        
        // Hide game world
        if let ground = ground {
            ground.isHidden = true
        }
        if let player = player {
            player.isHidden = true
        }
        worldNode.isHidden = true
    }
    
    private func showGameElements() {
        distanceLabel.isHidden = false
        highScoreLabel.isHidden = false
        gameMenuButton.isHidden = false
        gameMenuButtonBackground.isHidden = false
        
        // Show game world
        if let ground = ground {
            ground.isHidden = false
        }
        if let player = player {
            player.isHidden = false
        }
        worldNode.isHidden = false
    }
    
    private func updateVolumeDisplay() {
        volumeLabel.text = "Volume: \(Int(volume * 100))%"
        volumeSliderKnob.position.x = volumeSliderBackground.position.x - 90 + CGFloat(volume) * 180
    }
    
    private func showResetConfirmation() {
        showingResetConfirmation = true
        confirmResetLabel.isHidden = false
        confirmYesButton.isHidden = false
        confirmNoButton.isHidden = false
        
        // Hide other settings elements temporarily
        volumeLabel.isHidden = true
        volumeSliderBackground.isHidden = true
        volumeSliderKnob.isHidden = true
        resetHighScoreButton.isHidden = true
    }
    
    private func hideResetConfirmation() {
        showingResetConfirmation = false
        confirmResetLabel.isHidden = true
        confirmYesButton.isHidden = true
        confirmNoButton.isHidden = true
        
        // Show settings elements again
        volumeLabel.isHidden = false
        volumeSliderBackground.isHidden = false
        volumeSliderKnob.isHidden = false
        resetHighScoreButton.isHidden = false
    }
    
    private func cleanupGameWorld() {
        // Remove all obstacles and their visual nodes
        obstacles.removeAll()
        obstacleNodes.forEach { $0.removeFromParent() }
        obstacleNodes.removeAll()
        
        // Remove ground and player if they exist
        if let ground = ground {
            ground.removeFromParent()
            self.ground = nil
        }
        if let player = player {
            player.removeFromParent()
            self.player = nil
        }
    }
    
    // MARK: - Settings Management
    private func loadSettings() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let settingsPath = (documentsPath as NSString).appendingPathComponent(".swiftdash_settings")
        
        do {
            let settingsString = try String(contentsOfFile: settingsPath, encoding: .utf8)
            if let volumeValue = Float(settingsString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                volume = max(0.0, min(1.0, volumeValue))
            }
        } catch {
            volume = 1.0 // Default volume
        }
    }
    
    private func saveSettings() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let settingsPath = (documentsPath as NSString).appendingPathComponent(".swiftdash_settings")
        
        do {
            try String(volume).write(toFile: settingsPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    // MARK: - Game Logic
    private func startGame() {
        gameState = .playing
        distance = 0
        speedMultiplier = 1.0 // Reset speed multiplier
        playerVelocityY = 0
        
        // Clean up any existing game world first
        cleanupGameWorld()
        
        // Setup game world fresh each time
        setupGround()
        setupPlayer()
        
        // Reset player position
        playerY = currentLayout.playerGroundY
        player.position = CGPoint(x: currentLayout.playerX, y: playerY)
        
        // Clear obstacles
        obstacles.removeAll()
        obstacleNodes.forEach { $0.removeFromParent() }
        obstacleNodes.removeAll()
        
        // Seed initial obstacles
        seedInitialObstacles()
        
        // Show game elements and hide menu
        hideAllMenuElements()
        showGameElements()
        
        // Hide game over UI
        gameOverLabel.isHidden = true
        restartLabel.isHidden = true
        cooldownLabel.isHidden = true
        
        updateUI()
    }
    
    private func updateGame(currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        // Update distance
        distance += 1
        
        // Apply physics scaled by game speed
        let physicsScale = CGFloat(speedMultiplier)
        playerVelocityY += GameConstants.gravity * physicsScale
        playerY += playerVelocityY * physicsScale
        
        // Ground collision
        if playerY <= currentLayout.playerGroundY {
            playerY = currentLayout.playerGroundY
            playerVelocityY = 0
        }
        
        if let player = player {
            player.position.y = playerY
        }
        
        // Move obstacles
        moveObstacles()
        
        // Spawn new obstacles
        spawnObstacles()
        
        // Check collisions
        checkCollisions()
        
        // Accelerate game speed
        speedMultiplier *= GameConstants.speedMultiplierIncrease
        
        updateUI()
    }
    
    private func moveObstacles() {
        let moveDistance: CGFloat = GameConstants.baseObstacleSpeed * CGFloat(speedMultiplier)
        
        for i in 0..<obstacles.count {
            obstacles[i].x -= moveDistance
        }
        
        // Update obstacle node positions
        for i in 0..<obstacleNodes.count {
            obstacleNodes[i].position.x -= moveDistance
        }
        
        // Remove obstacles that are off screen
        let offScreenX: CGFloat = -50
        obstacles = obstacles.filter { $0.x > offScreenX }
        
        // Remove corresponding nodes
        obstacleNodes = obstacleNodes.filter { node in
            if node.position.x < offScreenX {
                node.removeFromParent()
                return false
            }
            return true
        }
    }
    
    private func spawnObstacles() {
        let furthestX = obstacles.map { $0.x }.max() ?? 0
        let spawnThreshold = size.width + 100
        
        if furthestX < spawnThreshold && Double.random(in: 0...1) < GameConstants.obstacleSpawnProbability {
            let spawnX = size.width + CGFloat.random(in: 0...200)
            let obstacleType: ObstacleType = Double.random(in: 0...1) < GameConstants.rockProbability ? .rock : .hole
            
            // Check minimum distance from last obstacle
            let lastObstacleX = obstacles.map { $0.x }.max() ?? 0
            if spawnX - lastObstacleX >= CGFloat(GameConstants.minGapCells) {
                let obstacle = Obstacle(x: spawnX, type: obstacleType)
                obstacles.append(obstacle)
                
                // Create visual node
                let obstacleNode = createObstacleNode(type: obstacleType)
                let yPosition = obstacleType == .rock ? currentLayout.groundY + layout.groundThickness/2 + 15 : currentLayout.groundY
                obstacleNode.position = CGPoint(x: spawnX, y: yPosition)
                obstacleNode.zPosition = 5
                addChild(obstacleNode)
                obstacleNodes.append(obstacleNode)
            }
        }
    }
    
    private func createObstacleNode(type: ObstacleType) -> SKSpriteNode {
        switch type {
        case .rock:
            let rock = SKSpriteNode(color: .gray, size: CGSize(width: 30, height: 30))
            // Make it look more like a rock
            rock.name = "rock"
            return rock
        case .hole:
            let hole = SKSpriteNode(color: .black, size: CGSize(width: 40, height: 20))
            hole.name = "hole"
            return hole
        }
    }
    
    private func checkCollisions() {
        let playerBounds = CGRect(
            x: currentLayout.playerX - layout.playerSize.width/2, 
            y: playerY - layout.playerSize.height/2, 
            width: layout.playerSize.width, 
            height: layout.playerSize.height
        )
        
        for obstacle in obstacles {
            let obstacleX = obstacle.x
            let obstacleBounds: CGRect
            
            switch obstacle.type {
            case .rock:
                obstacleBounds = CGRect(x: obstacleX - 15, y: currentLayout.groundY + layout.groundThickness/2, width: 30, height: 30)
            case .hole:
                obstacleBounds = CGRect(x: obstacleX - 20, y: currentLayout.groundY - 10, width: 40, height: 20)
            }
            
            if playerBounds.intersects(obstacleBounds) {
                handleCollision(with: obstacle)
                break
            }
        }
    }
    
    private func handleCollision(with obstacle: Obstacle) {
        switch obstacle.type {
        case .hole:
            // Only collide if player is on ground
            if playerY <= currentLayout.playerGroundY + 20 {
                gameOver()
            }
        case .rock:
            // Only collide if player is on ground
            if playerY <= currentLayout.playerGroundY + 20 {
                gameOver()
            }
        }
    }
    
    private func gameOver() {
        gameState = .gameOver
        
        // Update high score
        if distance > highScore {
            highScore = distance
            saveHighScore()
        }
        
        // Show game over UI
        gameOverLabel.isHidden = false
        restartLabel.isHidden = false
        
        // Start cooldown
        cooldownEndTime = CACurrentMediaTime() + GameConstants.cooldownSeconds
        gameState = .cooldown
        cooldownLabel.isHidden = false
        
        updateUI()
    }
    
    private func updateUI() {
        distanceLabel.text = "Distance: \(distance)"
        highScoreLabel.text = "High Score: \(highScore)"
        
        if gameState == .cooldown {
            let remainingTime = max(0, Int(cooldownEndTime - CACurrentMediaTime()))
            if remainingTime > 0 {
                cooldownLabel.text = "Restart in \(remainingTime) seconds..."
            } else {
                cooldownLabel.text = "Jump to restart"
                gameState = .gameOver
            }
        }
    }
    
    // MARK: - Obstacle Generation
    private func seedInitialObstacles() {
        // Ensure guaranteed safe space in front of player
        let safeDistance: CGFloat = 300 // Guaranteed safe distance in front of player
        let safeUntilX = currentLayout.playerX + safeDistance
        
        // Spawn obstacles beyond the safe zone
        for x in stride(from: safeUntilX + CGFloat(GameConstants.minGapCells), to: size.width + 400, by: CGFloat(GameConstants.minGapCells)) {
            if Double.random(in: 0...1) < GameConstants.obstacleSpawnProbability {
                let obstacleType: ObstacleType = Double.random(in: 0...1) < GameConstants.rockProbability ? .rock : .hole
                let obstacle = Obstacle(x: x, type: obstacleType)
                obstacles.append(obstacle)
                
                // Create visual node
                let obstacleNode = createObstacleNode(type: obstacleType)
                let yPosition = obstacleType == .rock ? currentLayout.groundY + layout.groundThickness/2 + 15 : currentLayout.groundY
                obstacleNode.position = CGPoint(x: x, y: yPosition)
                obstacleNode.zPosition = 5
                addChild(obstacleNode)
                obstacleNodes.append(obstacleNode)
            }
        }
    }
    
    // MARK: - High Score Persistence
    private func getHighScorePath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return (documentsPath as NSString).appendingPathComponent(".swiftdash_highscore")
    }
    
    private func loadHighScore() {
        let path = getHighScorePath()
        do {
            let scoreString = try String(contentsOfFile: path, encoding: .utf8)
            if let score = Int(scoreString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                highScore = max(0, score)
            }
        } catch {
            highScore = 0
        }
    }
    
    private func saveHighScore() {
        let path = getHighScorePath()
        do {
            try String(highScore).write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save high score: \(error)")
        }
    }
    
    // MARK: - Input Handling
    private func handleJump() {
        switch gameState {
        case .mainMenu, .settings:
            // In menu states, do nothing - handle with touch/click events
            break
        case .playing:
            // Only jump if on ground
            if playerY <= currentLayout.playerGroundY + 20 {
                playerVelocityY = GameConstants.jumpVelocity // Jump up
            }
        case .gameOver:
            // Allow restart immediately when countdown is done
            startGame()
        case .cooldown:
            // Do nothing during cooldown
            break
        }
    }
    
    private func handleMenuTouch(at location: CGPoint) {
        // Check which UI element was touched
        let touchedNodes = nodes(at: location)
        
        for node in touchedNodes {
            guard let nodeName = node.name else { continue }
            
            // Visual feedback - briefly change color
            if let labelNode = node as? SKLabelNode {
                let originalColor = labelNode.fontColor
                labelNode.fontColor = .yellow
                labelNode.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.1),
                    SKAction.run { labelNode.fontColor = originalColor }
                ]))
            }
            
            switch nodeName {
            case "playButton":
                if gameState == .mainMenu {
                    startGame()
                }
            case "settingsButton":
                if gameState == .mainMenu {
                    showSettings()
                }
            case "backButton":
                if gameState == .settings && !showingResetConfirmation {
                    showMainMenu()
                }
            case "gameMenuButton", "gameMenuButtonBackground":
                if gameState == .playing || gameState == .gameOver || gameState == .cooldown {
                    showMainMenu()
                }
            case "resetHighScoreButton":
                if gameState == .settings && !showingResetConfirmation {
                    showResetConfirmation()
                }
            case "confirmYes":
                if showingResetConfirmation {
                    highScore = 0
                    saveHighScore()
                    hideResetConfirmation()
                }
            case "confirmNo":
                if showingResetConfirmation {
                    hideResetConfirmation()
                }
            case "volumeSlider", "volumeKnob":
                if gameState == .settings && !showingResetConfirmation {
                    handleVolumeChange(at: location)
                }
            default:
                break
            }
        }
    }
    
    private func handleVolumeChange(at location: CGPoint) {
        // Calculate new volume based on touch position
        let sliderLeft = volumeSliderBackground.position.x - 90
        let sliderRight = volumeSliderBackground.position.x + 90
        let touchX = max(sliderLeft, min(sliderRight, location.x))
        
        volume = Float((touchX - sliderLeft) / (sliderRight - sliderLeft))
        updateVolumeDisplay()
        saveSettings()
    }
    
    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
        }
        
        let deltaTime = currentTime - lastUpdateTime
        
        if deltaTime >= GameConstants.targetFrameRate {
            updateGame(currentTime: currentTime)
            lastUpdateTime = currentTime
        }
        
        // Update UI every frame for countdown
        updateUI()
    }
}

// MARK: - Touch/Mouse Handling
#if os(iOS) || os(tvOS)
extension GameScene {
    
    @objc private func handleLeftEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        // Only handle completed swipes
        guard gesture.state == .ended else { return }
        
        // Only allow back gesture during gameplay, game over, or cooldown states
        if gameState == .playing || gameState == .gameOver || gameState == .cooldown {
            showMainMenu()
        } else if gameState == .settings && !showingResetConfirmation {
            showMainMenu()
        } else if gameState == .settings && showingResetConfirmation {
            hideResetConfirmation()
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        // Handle menu interactions
        if gameState == .mainMenu || gameState == .settings {
            handleMenuTouch(at: location)
            
            // iOS workaround: Double-tap anywhere in settings to go back
            #if os(iOS)
            if gameState == .settings && !showingResetConfirmation && touch.tapCount == 2 {
                showMainMenu()
                return
            }
            #endif
        } else if gameState == .playing || gameState == .gameOver || gameState == .cooldown {
            // Check if touching the menu button
            let touchedNodes = nodes(at: location)
            var menuButtonTouched = false
            for node in touchedNodes {
                if node.name == "gameMenuButton" || node.name == "gameMenuButtonBackground" {
                    handleMenuTouch(at: location)
                    menuButtonTouched = true
                    break
                }
            }
            
            // If not touching menu button, handle jump
            if !menuButtonTouched {
                handleJump()
            }
        } else {
            handleJump()
        }
    }
}
#endif

#if os(OSX)
extension GameScene {
    override func keyDown(with event: NSEvent) {
        // Handle menu navigation with keyboard
        if gameState == .settings && event.keyCode == 53 { // Escape key
            if showingResetConfirmation {
                hideResetConfirmation()
            } else {
                showMainMenu()
            }
            return
        } else if gameState == .mainMenu && event.keyCode == 53 { // Escape key
            NSApplication.shared.terminate(nil)
            return
        }
        
        switch event.keyCode {
        case 49: // Space
            handleJump()
        case 13: // W
            handleJump()
        case 12: // Q
            NSApplication.shared.terminate(nil)
        default:
            break
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        
        // Handle menu interactions
        if gameState == .mainMenu || gameState == .settings {
            handleMenuTouch(at: location)
        } else if gameState == .playing || gameState == .gameOver || gameState == .cooldown {
            // Check if clicking the menu button
            let touchedNodes = nodes(at: location)
            var menuButtonTouched = false
            for node in touchedNodes {
                if node.name == "gameMenuButton" || node.name == "gameMenuButtonBackground" {
                    handleMenuTouch(at: location)
                    menuButtonTouched = true
                    break
                }
            }
            
            // If not clicking menu button, handle jump
            if !menuButtonTouched {
                handleJump()
            }
        } else {
            handleJump()
        }
    }
}
#endif

