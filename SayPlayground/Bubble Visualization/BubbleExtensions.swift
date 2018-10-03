//
//  ViewController.swift
//  SayPlayground
//
//  Created by Stephen Silber on 10/3/18.
//  Copyright © 2018 say. All rights reserved.
//

import UIKit

extension Array {
    
    func randomItem() -> Element {
        return self[Int.random(in: 0..<count)]
    }
    
}

extension CGPoint {
    
    func distance(from point: CGPoint) -> CGFloat {
        return hypot(point.x - x, point.y - y)
    }
    
}
