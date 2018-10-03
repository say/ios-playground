//
//  DebugSettingsViewController.swift
//  Say
//
//  Created by Stephen Silber on 5/8/18.
//  Copyright © 2018 Say. All rights reserved.
//

import Foundation
import AsyncDisplayKit

class PlaygroundOptionViewController: ASViewController<PlaygroundOptionListNode> {
    
    var didSelectOption: ((PlaygroundOption) -> Void)? 
    private var items: [Item] = []

    init() {
        super.init(node: PlaygroundOptionListNode())
        
        let options = [
            PlaygroundOption.bubbleVisualization,
            PlaygroundOption.particleSimulator
        ]
        
        self.items = options.map { option in
            let cellBlock: ASCellNodeBlock = {
                let node = ASTextCellNode()
                node.text = option.readableString
                return node
            }
            
            return Item(identifier: option.readableString, cellBlock: cellBlock, selectionBlock: { [weak self] _ in
                self?.didSelectOption?(option)
                
            })
        }
        
        node.delegate = self
        node.dataSource = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Select a Playground"
    }
}



extension PlaygroundOptionViewController: ASTableDataSource {
    
    func numberOfSections(in tableNode: ASTableNode) -> Int {
        return 1
    }
    
    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return items[indexPath.row].cellBlock
    }
    
}


extension PlaygroundOptionViewController: ASTableDelegate {
    
    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        tableNode.deselectRow(at: indexPath, animated: true)
        items[indexPath.row].selectionBlock?(indexPath)
    }
    
}

