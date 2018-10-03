//
//  Extensions.swift
//  SayPlayground
//
//  Created by Stephen Silber on 10/3/18.
//  Copyright © 2018 say. All rights reserved.
//

import UIKit
import Foundation
import ObjectiveC
import AsyncDisplayKit

private var blockAssociationKey: Int = 0

extension ASControlNode {
    
    public convenience init(with block: @escaping () -> Void) {
        self.init()
        self.block = block
    }
    
    public var block: (() -> Void)? {
        get {
            return objc_getAssociatedObject(self, &blockAssociationKey) as? () -> Void
        }
        set {
            removeTarget(self, action:  #selector(handler), forControlEvents: [.touchUpInside])
            
            if newValue != nil {
                addTarget(self, action: #selector(handler), forControlEvents: [.touchUpInside])
            }
            
            objc_setAssociatedObject(self, &blockAssociationKey, newValue, .OBJC_ASSOCIATION_COPY)
        }
    }
    
    @objc private func handler() {
    }
    
}


func create<T>(_ setup: ((T) -> Void)) -> T where T: NSObject {
    let obj = T()
    setup(obj)
    return obj
}

extension UIColor {
    
    public convenience init(hex: UInt32, includesAlpha: Bool = false) {
        var a = CGFloat(1)
        if includesAlpha {
            a = CGFloat((hex >> 24) & 0xFF) / 255
        }
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    public convenience init?(hexString: String) {
        var cString:String = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }
        
        if ((cString.count) != 6) {
            return nil
        }
        
        var rgbValue:UInt32 = 0
        Scanner(string: cString).scanHexInt32(&rgbValue)
        
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                  green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
                  blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
                  alpha: CGFloat(1.0))
    }
    
    convenience init(red: Int, green: Int, blue: Int) {
        self.init(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
    
}

