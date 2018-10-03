//
//  NSAttributedString+Path.swift
//  MetalParticles
//
//  Created by Stephen Silber on 8/15/18.
//  Copyright © 2018 Stephen Silber. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreText

extension NSAttributedString {

    var path: CGPath? {
        
        let letters = CGMutablePath()
        
        let line = CTLineCreateWithAttributedString(self)
        let runArray = CTLineGetGlyphRuns(line)
        
        (0..<CFArrayGetCount(runArray)).forEach { index in
            let runPointer = CFArrayGetValueAtIndex(runArray, index)
            let run = unsafeBitCast(runPointer, to: CTRun.self)
            let attribs = CTRunGetAttributes(run)
            let fontPointer = CFDictionaryGetValue(attribs, Unmanaged.passUnretained(kCTFontAttributeName).toOpaque())
            let font = unsafeBitCast(fontPointer, to: CTFont.self)

            (0..<CTRunGetGlyphCount(run)).forEach { index in
                let glyphRange = CFRangeMake(index, 1)
                var glyph = CGGlyph()
                var position = CGPoint.zero

                CTRunGetGlyphs(run, glyphRange, &glyph)
                CTRunGetPositions(run, glyphRange, &position)

                // Get path of outline
                guard let letter = CTFontCreatePathForGlyph(font, glyph, nil) else {
                    return
                }
                
                let transform = CGAffineTransform(translationX: position.x, y: position.y)
                letters.addPath(letter, transform: transform)
            }
        }
        
        return letters.copy()
    }

}
