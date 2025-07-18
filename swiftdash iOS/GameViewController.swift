//
//  GameViewController.swift
//  swiftdash iOS
//
//  Created by Kris Furman on 08/07/2025.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = GameScene.newGameScene()

        // Present the scene
        let skView = self.view as! SKView
        skView.presentScene(scene)
        
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Force landscape-only for optimal endless runner gameplay
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
