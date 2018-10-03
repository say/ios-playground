//
//  BubbleRootNode.swift
//  SayPlayground
//
//  Created by Stephen Silber on 10/3/18.
//  Copyright © 2018 say. All rights reserved.
//

import SpriteKit
import Magnetic
import AsyncDisplayKit

class BubbleRootNode: ASDisplayNode {
    
    lazy var magneticView: MagneticView = {
        let magneticView = MagneticView(frame: UIApplication.shared.keyWindow?.bounds ?? .zero)
        magneticView.backgroundColor = .white
        //        magnetic.magneticDelegate = self
        //        magnetic.allowsMultipleSelection = false
        #if DEBUG
        magneticView.showsFPS = true
        magneticView.showsDrawCount = true
        magneticView.showsQuadCount = true
        #endif
        
        return magneticView
    }()
    
    lazy var magneticViewNode: ASDisplayNode = {
        return ASDisplayNode(viewBlock: { () -> UIView in
            return self.magneticView
        })
    }()
    
    let resetButton: ASButtonNode = create {
        $0.setTitle("Reset", with: nil, with: .red, for: .normal)
    }
    
    let addButton: ASButtonNode = create {
        $0.setTitle("Add", with: nil, with: .red, for: .normal)
    }
    
    override init() {
        super.init()
        automaticallyManagesSubnodes = true
        automaticallyRelayoutOnSafeAreaChanges = true
        automaticallyRelayoutOnLayoutMarginsChanges = true
        
        backgroundColor = .white
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        
        let buttonStack = ASStackLayoutSpec(direction: .horizontal, spacing: 0, justifyContent: .spaceBetween, alignItems: .center, children: [resetButton, addButton])
        buttonStack.style.width = ASDimensionMakeWithFraction(1)
        
        let buttonStackInset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 10, left: 60, bottom: 10, right: 60), child: buttonStack)
        
        let stack = ASStackLayoutSpec(direction: .vertical, spacing: 20, justifyContent: .start, alignItems: .stretch, children: [magneticViewNode, buttonStackInset])
        stack.style.flexGrow = 1
        
        magneticViewNode.style.flexGrow = 1
        
        return ASInsetLayoutSpec(insets: safeAreaInsets, child: stack)
    }
}

