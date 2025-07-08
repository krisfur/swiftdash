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
    static let initialFrameRate: TimeInterval = 0.015 // Faster start (~40 FPS)
    static let minFrameRate: TimeInterval = 0.0167 // Cap at ~60 FPS
    static let accelerationFactor: Double = 0.9995 // More gradual speedup
    static let speedMultiplierIncrease: Double = 1.001 // Increase movement speed over time
    static let cooldownSeconds: TimeInterval = 2.0
    static let gravity: CGFloat = -1.0 // Gravity pulls down
    static let jumpVelocity: CGFloat = 16.0 // Higher jump
    static let minGapCells: Int = 150 // Much larger minimum gap for fairness
    static let initialSafeTiles: Int = 25
    static let obstacleSpawnProbability: Double = 0.12
    static let rockProbability: Double = 0.5
    static let baseObstacleSpeed: CGFloat = 5.0 // Base movement speed
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
    
    // MARK: - Game State
    private var gameState: GameState = .playing
    private var distance: Int = 0
    private var highScore: Int = 0
    private var frameDuration: TimeInterval = GameConstants.initialFrameRate
    private var lastUpdateTime: TimeInterval = 0
    private var speedMultiplier: Double = 1.0 // Tracks current game speed
    
    // MARK: - Player
    private var player: SKSpriteNode!
    private var playerVelocityY: CGFloat = 0
    private var playerY: CGFloat = 0
    private var groundY: CGFloat = 50 // Will be calculated based on screen size
    
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
        // Calculate ground position based on screen size
        groundY = size.height * 0.15 // 15% from bottom of screen
        
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
    
    private func setupGround() {
        ground = SKSpriteNode(color: .brown, size: CGSize(width: size.width * 2, height: 20))
        ground.position = CGPoint(x: size.width / 2, y: groundY)
        ground.zPosition = 1
        addChild(ground)
    }
    
    private func setupPlayer() {
        // Create a simple hamster sprite (placeholder)
        player = SKSpriteNode(color: .orange, size: CGSize(width: 30, height: 30))
        player.position = CGPoint(x: 100, y: groundY + 15) // Align with ground
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
        // Distance label
        distanceLabel = SKLabelNode(fontNamed: "Arial-Bold")
        distanceLabel.fontSize = 24
        distanceLabel.fontColor = .white
        distanceLabel.position = CGPoint(x: 100, y: size.height - 50)
        distanceLabel.zPosition = 100
        addChild(distanceLabel)
        
        // High score label
        highScoreLabel = SKLabelNode(fontNamed: "Arial")
        highScoreLabel.fontSize = 18
        highScoreLabel.fontColor = .yellow
        highScoreLabel.position = CGPoint(x: 100, y: size.height - 80)
        highScoreLabel.zPosition = 100
        addChild(highScoreLabel)
        
        // Game over label
        gameOverLabel = SKLabelNode(fontNamed: "Arial-Bold")
        gameOverLabel.fontSize = 48
        gameOverLabel.fontColor = .red
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        gameOverLabel.zPosition = 100
        gameOverLabel.isHidden = true
        addChild(gameOverLabel)
        
        // Restart label
        restartLabel = SKLabelNode(fontNamed: "Arial")
        restartLabel.fontSize = 24
        restartLabel.fontColor = .white
        restartLabel.text = "Jump to restart"
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
        restartLabel.zPosition = 100
        restartLabel.isHidden = true
        addChild(restartLabel)
        
        // Cooldown label
        cooldownLabel = SKLabelNode(fontNamed: "Arial")
        cooldownLabel.fontSize = 20
        cooldownLabel.fontColor = .orange
        cooldownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        cooldownLabel.zPosition = 100
        cooldownLabel.isHidden = true
        addChild(cooldownLabel)
        
        updateUI()
    }
    
    // Handle window resize
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        
        // Recalculate ground position based on new screen size
        groundY = size.height * 0.15 // 15% from bottom of screen
        
        // Update ground position and size (only if ground exists)
        if let ground = ground {
            ground.size = CGSize(width: size.width * 2, height: 20)
            ground.position = CGPoint(x: size.width / 2, y: groundY)
        }
        
        // Update player position to stay on ground (only if player exists)
        if let player = player {
            playerY = groundY + 15
            player.position.y = playerY
        }
        
        // Update UI positions (only if UI elements exist)
        if let distanceLabel = distanceLabel {
            distanceLabel.position = CGPoint(x: 100, y: size.height - 50)
        }
        if let highScoreLabel = highScoreLabel {
            highScoreLabel.position = CGPoint(x: 100, y: size.height - 80)
        }
        if let gameOverLabel = gameOverLabel {
            gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 50)
        }
        if let restartLabel = restartLabel {
            restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)
        }
        if let cooldownLabel = cooldownLabel {
            cooldownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        }
    }
    
    // MARK: - Game Logic
    private func startGame() {
        gameState = .playing
        distance = 0
        frameDuration = GameConstants.initialFrameRate
        speedMultiplier = 1.0 // Reset speed multiplier
        playerVelocityY = 0
        playerY = groundY + 15 // Align with ground
        player.position.y = playerY
        
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
        if playerY <= groundY + 15 {
            playerY = groundY + 15
            playerVelocityY = 0
        }
        
        player.position.y = playerY
        
        // Move obstacles
        moveObstacles()
        
        // Spawn new obstacles
        spawnObstacles()
        
        // Check collisions
        checkCollisions()
        
        // Accelerate game
        frameDuration *= GameConstants.accelerationFactor
        // Cap frame rate at 60 FPS but allow speed multiplier to continue increasing
        frameDuration = max(frameDuration, GameConstants.minFrameRate)
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
                obstacleNode.position = CGPoint(x: spawnX, y: obstacleType == .rock ? groundY + 15 : groundY)
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
        let playerX = player.position.x
        let playerBounds = CGRect(x: playerX - 15, y: playerY - 15, width: 30, height: 30)
        
        for obstacle in obstacles {
            let obstacleX = obstacle.x
            let obstacleBounds: CGRect
            
            switch obstacle.type {
            case .rock:
                obstacleBounds = CGRect(x: obstacleX - 15, y: groundY, width: 30, height: 30)
            case .hole:
                obstacleBounds = CGRect(x: obstacleX - 20, y: groundY - 10, width: 40, height: 20)
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
            if playerY <= groundY + 20 {
                gameOver()
            }
        case .rock:
            // Only collide if player is on ground
            if playerY <= groundY + 20 {
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
        // Ensure guaranteed safe space in front of player (like in GopherDash)
        let playerX: CGFloat = 100 // Player's X position
        let safeDistance: CGFloat = 300 // Guaranteed safe distance in front of player
        let safeUntilX = playerX + safeDistance
        
        // Spawn obstacles beyond the safe zone
        for x in stride(from: safeUntilX + CGFloat(GameConstants.minGapCells), to: size.width + 400, by: CGFloat(GameConstants.minGapCells)) {
            if Double.random(in: 0...1) < GameConstants.obstacleSpawnProbability {
                let obstacleType: ObstacleType = Double.random(in: 0...1) < GameConstants.rockProbability ? .rock : .hole
                let obstacle = Obstacle(x: x, type: obstacleType)
                obstacles.append(obstacle)
                
                // Create visual node
                let obstacleNode = createObstacleNode(type: obstacleType)
                obstacleNode.position = CGPoint(x: x, y: obstacleType == .rock ? groundY + 15 : groundY)
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
            if playerY <= groundY + 20 {
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
        
        if deltaTime >= frameDuration {
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

