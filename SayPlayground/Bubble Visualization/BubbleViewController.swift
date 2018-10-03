//
//  ViewController.swift
//  SayPlayground
//
//  Created by Stephen Silber on 10/3/18.
//  Copyright © 2018 say. All rights reserved.
//

import SpriteKit
import Magnetic
import AsyncDisplayKit

class BubbleViewController: ASViewController<BubbleRootNode> {
    
    private let defaultSize: CGFloat = 6
    
    var magnetic: Magnetic {
        return node.magneticView.magnetic
    }
    
    var count: Int = 0
    private let initialCount: Int
    
    init(count: Int) {
        self.initialCount = count
        super.init(node: BubbleRootNode())
        
        node.addButton.addTarget(self, action: #selector(handleAddTouchDown), forControlEvents: .touchDown)
        node.addButton.addTarget(self, action: #selector(handleAddTouchUpInside), forControlEvents: .touchUpInside)
        node.addButton.addTarget(self, action: #selector(handleAddTouchUpOutside), forControlEvents: .touchUpOutside)
        
        node.resetButton.addTarget(self, action: #selector(handleResetButton), forControlEvents: .touchUpInside)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        magnetic.magneticField.strength *= 10
        
        (0..<initialCount).forEach { _ in
            add()
        }
    }
    
    func add() {
        
        // Generate random for/against bubble
        let vote: Vote = Int.random(in: 0...1) == 0 ? .for : .against
        
        // Adjust the variable radius for bubbles here
        let radius = CGFloat.random(in: 2...12)
        
        let node = Bubble(vote: vote, radius: radius)
        
        magnetic.addChild(node)
        count += 1
    }
    
    
    private func resetChildren(with count: Int) {
    
        let speed = magnetic.physicsWorld.speed
        magnetic.physicsWorld.speed = 0.0
        
        let sortedNodes = magnetic.children.compactMap { $0 as? Bubble }
        var actions = [SKAction]()
        for (index, node) in sortedNodes.enumerated() {
            node.physicsBody = nil
            let action = SKAction.run { [unowned magnetic, unowned node] in
                if node.isSelected {
                    let point = CGPoint(x: magnetic.size.width / 2, y: magnetic.size.height + node.frame.height)
                    let movingXAction = SKAction.moveTo(x: point.x, duration: 0.2)
                    let movingYAction = SKAction.moveTo(y: point.y, duration: 0.4)
                    let resize = SKAction.scale(to: 2.3, duration: 0.4)
                    let throwAction = SKAction.group([movingXAction, movingYAction, resize])
                    node.run(throwAction) { [unowned node] in
                        node.removeFromParent()
                    }
                } else {
                    node.removeFromParent()
                }
            }
            actions.append(action)
            let delay = SKAction.wait(forDuration: TimeInterval(index) * 0.002)
            actions.append(delay)
        }
        
        magnetic.run(.sequence(actions)) { [unowned magnetic] in
            magnetic.physicsWorld.speed = speed
        }
    }
    
    @objc private func handleResetButton() {
        let alert = UIAlertController(title: "Choose Node Count", message: "The higher the number of nodes, the less performant this will be", preferredStyle: .actionSheet)
        let low = UIAlertAction(title: "100", style: .default) { [weak self] _ in
            self?.resetChildren(with: 100)
        }
        
        let medium = UIAlertAction(title: "500", style: .default) { [weak self] _ in
            self?.resetChildren(with: 500)
        }
        
        let high = UIAlertAction(title: "1000", style: .default) { [weak self] _ in
            self?.resetChildren(with: 1000)
        }
        
        let extra = UIAlertAction(title: "2500", style: .default) { [weak self] _ in
            self?.resetChildren(with: 2500)
        }
        
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        alert.addAction(low)
        alert.addAction(medium)
        alert.addAction(high)
        alert.addAction(extra)
        alert.addAction(cancel)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: Add button and timers
    
    private var addHoldTimerInterval: TimeInterval = 0.05
    private var addHoldTimer: Timer?
    private var addHoldCount: Int = 0
    private var addHoldDelayTimer: Timer?
    
    private func setupHoldTimer() {
        print("Setting up hold timer with interval: \(addHoldTimerInterval)")
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        addHoldTimer = Timer.scheduledTimer(withTimeInterval: addHoldTimerInterval, repeats: true, block: { [unowned self] timer in
            self.add()
            self.addHoldCount += 1
            
            if self.addHoldCount > 20 {
                self.addHoldCount = 0
                
                self.addHoldTimerInterval = max(0.0001, self.addHoldTimerInterval / 2)
                
                timer.invalidate()
                self.setupHoldTimer()
            }
        })
    }
    
    private func resetHoldTimer() {
        addHoldTimer?.invalidate()
        addHoldDelayTimer?.invalidate()
        addHoldCount = 0
        addHoldTimerInterval = 0.05

    }
    
    @objc private func handleAddTouchDown() {
        addHoldDelayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { [weak self] timer in
            timer.invalidate()
            self?.setupHoldTimer()
        })
        
    }
    
    @objc private func handleAddTouchUpInside() {
        resetHoldTimer()
        add()
    }
    
    @objc private func handleAddTouchUpOutside() {
        resetHoldTimer()
    }
    
}

// MARK: - MagneticDelegate
extension BubbleViewController: MagneticDelegate {
    
    func magnetic(_ magnetic: Magnetic, didSelect node: Node) {
        print("didSelect -> \(node)")
    }
    
    func magnetic(_ magnetic: Magnetic, didDeselect node: Node) {
        print("didDeselect -> \(node)")
    }
    
}
