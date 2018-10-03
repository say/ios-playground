//
//  DebugSetting.swift
//  Say
//
//  Created by Stephen Silber on 5/8/18.
//  Copyright © 2018 Say. All rights reserved.
//

import Foundation

enum PlaygroundOption: String {
    
    case particleSimulator = "particleSimulator"
    case bubbleVisualization = "bubbleVisualization"

    var readableString: String {
        switch self {
        case .particleSimulator:
            return "Particle simulator"
            
        case .bubbleVisualization:
            return "Bubble visualization"
        
        }
    }
    
    // MARK: Helpers
    private static let keyPrefix = "com.mobile.say.playground-"
    
    var notificationName: Notification.Name {
        return Notification.Name(rawValue: key + "-changed")
    }
    
    var key: String {
        return PlaygroundOption.keyPrefix + rawValue
    }
    
    var currentValue: Bool {
        return UserDefaults.standard.bool(forKey: key)
    }
    
    func updateValue(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
        NotificationCenter.default.post(Notification(name: notificationName))
    }
}
