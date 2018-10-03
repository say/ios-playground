//
//  Bubble.swift
//  SayPlayground
//
//  Created by Stephen Silber on 10/3/18.
//  Copyright © 2018 say. All rights reserved.
//

import SpriteKit

@objcMembers open class Bubble: SKShapeNode {
    
    public lazy var sprite: SKSpriteNode = { [unowned self] in
        let sprite = SKSpriteNode()
        sprite.size = self.frame.size
        return sprite
        }()
    
    private(set) var texture: SKTexture?
    
    /**
     The selection state of the node.
     */
    open var isSelected: Bool = false {
        didSet {
            guard isSelected != oldValue else { return }
            if isSelected {
                selectedAnimation()
            } else {
                deselectedAnimation()
            }
        }
    }
    
    let vote: Vote
    let node: SKShapeNode
    
    public var shouldSpawnInCenter: Bool = false
    
    // The scale of growing when a node is selected
    private let selectedScale: CGFloat = 4.0
    private let isHitCollisionEnabled: Bool = true
    
    
    /**
     Creates a node object.
     
     - Parameters:
     - vote: The vote represented by the node.
     - radius: The radius of the node.
     
     - Returns: A new node.
     */
    public init(vote: Vote, radius: CGFloat) {
        
        self.vote = vote
        node = SKShapeNode(circleOfRadius: radius)
        
        super.init()
        
        node.fillColor = vote.color
        node.strokeColor = .clear
        
        self.addChild(node)
        
        self.physicsBody =  {
            let body = SKPhysicsBody(circleOfRadius: radius + 0.5)
            body.allowsRotation = false
            body.friction = 0
            body.linearDamping = 3
            body.restitution = 0.5
            
            if !isHitCollisionEnabled {
                body.collisionBitMask = 0
            }
            
            // This improves performance with high node counts
            body.usesPreciseCollisionDetection = false
            
            return body
        }()
        
        self.fillColor = .white
        self.strokeColor = .clear
        
        _ = self.sprite
        
        configure(color: vote.color)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open func configure(color: UIColor) {
        self.node.fillColor = color
    }
    
    override open func removeFromParent() {
        removedAnimation() {
            super.removeFromParent()
        }
    }
    
    /**
     The animation to execute when the node is selected.
     */
    open func selectedAnimation() {
        run(.scale(to: selectedScale, duration: 0.2))
        if let texture = texture {
            sprite.run(.setTexture(texture))
        }
    }
    
    /**
     The animation to execute when the node is deselected.
     */
    open func deselectedAnimation() {
        run(.scale(to: 1, duration: 0.2))
        sprite.texture = nil
    }
    
    /**
     The animation to execute when the node is removed.
     
     - important: You must call the completion block.
     
     - parameter completion: The block to execute when the animation is complete. You must call this handler and should do so as soon as possible.
     */
    open func removedAnimation(completion: @escaping () -> Void) {
        run(.fadeOut(withDuration: 0.2), completion: completion)
    }
    
}
