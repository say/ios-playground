//
//  Vote.swift.swift
//  Example
//
//  Created by Stephen Silber on 10/2/18.
//  Copyright © 2018 efremidze. All rights reserved.
//

import UIKit

public enum Vote {
    case `for`
    case against
    
    public var color: UIColor {
        switch self {
        case .for:
            return UIColor(hexString: "#11CC99")!

        case .against:
            return UIColor(hexString: "#333333")!
            
        }
    }
}
