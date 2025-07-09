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
    case playing
    case gameOver
    case cooldown
}

class GameScene: SKScene {
    
    // MARK: - Layout
    private let layout = LayoutConfig()
    
    // MARK: - Game State
    private var gameState: GameState = .playing
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
    
    // MARK: - Game World
    private var ground: SKSpriteNode!
    private var worldNode: SKNode!
    
    // MARK: - Cooldown
    private var cooldownEndTime: TimeInterval = 0
    
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
        startGame()
    }
    
    private func setupScene() {
        // Calculate initial layout
        updateLayout()
        
        // Setup world container
        worldNode = SKNode()
        addChild(worldNode)
        
        // Setup ground
        setupGround()
        
        // Setup player
        setupPlayer()
        
        // Setup UI
        setupUI()
        
        // Setup initial obstacles
        seedInitialObstacles()
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
    
    // MARK: - Game Logic
    private func startGame() {
        gameState = .playing
        distance = 0
        speedMultiplier = 1.0 // Reset speed multiplier
        playerVelocityY = 0
        playerY = currentLayout.playerGroundY
        if let player = player {
            player.position = CGPoint(x: currentLayout.playerX, y: playerY)
        }
        
        // Clear obstacles
        obstacles.removeAll()
        obstacleNodes.forEach { $0.removeFromParent() }
        obstacleNodes.removeAll()
        
        // Seed initial obstacles
        seedInitialObstacles()
        
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
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleJump()
    }
}
#endif

#if os(OSX)
extension GameScene {
    override func keyDown(with event: NSEvent) {
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
        handleJump()
    }
}
#endif

