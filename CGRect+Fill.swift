//
//  CGRect+Fill.swift
//  MetalParticles
//
//  Created by Stephen Silber on 8/16/18.
//  Copyright © 2018 Stephen Silber. All rights reserved.
//

import CoreGraphics

extension CGRect {
    func generatePointsInside(path: CGPath? = nil, count: Int) -> [CGPoint] {
        guard count > 0 else {
            return []
        }
        
        let area = width * height
        
        let density = area / CGFloat(count)
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        
        var points: [CGPoint] = []
        
        while points.count < count {
            let point = CGPoint(x: x + origin.x, y: y + origin.y)
            
            if path?.contains(point) == true || (path == nil && self.contains(point)) {
                points.append(point)
            }
            
            x += density
            
            if x >= width {
                x = 0
                y += density
            }
            
            if y >= width {
                y = density / 2
                x = density / 2
            }
        }
        
        return points
    }
    
    func generateRandomPointsInside(path: CGPath? = nil, count: Int) -> [CGPoint] {
        guard count > 0 else {
            return []
        }
        
        var points: [CGPoint] = []
        
        while points.count < count {
            let lowerX = origin.x < width ? origin.x : width
            let upperX = origin.x > width ? origin.x : width
            
            let lowerY = origin.y < height ? origin.y : height
            let upperY = origin.y > height ? origin.y : height
            
            let x = CGFloat.random(in: lowerX...upperX)
            let y = CGFloat.random(in: lowerY...upperY)
            
            let point = CGPoint(x: x, y: y)
            
            if path?.contains(point) == true || (path == nil && self.contains(point)) {
                points.append(point)
            }
        }
        
        return points
    }
    
}
