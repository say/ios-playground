//
//  DebugSettingListNode.swift
//  Say
//
//  Created by Stephen Silber on 5/8/18.
//  Copyright © 2018 Say. All rights reserved.
//

import Foundation
import AsyncDisplayKit

struct Item {
    var identifier: String
    var cellBlock: ASCellNodeBlock
    var selectionBlock: ((IndexPath) -> Void)?
}

class PlaygroundOptionListNode: ASTableNode {

}
