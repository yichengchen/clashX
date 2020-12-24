//
//  NSTextField+Vibrancy.swift
//  ClashX
//
//  Created by yicheng on 2019/11/1.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class VibrancyTextField: NSTextField {
    private var _allowsVibrancy = true
    override var allowsVibrancy: Bool {
        return _allowsVibrancy
    }

    func setup(allowsVibrancy: Bool) -> Self {
        _allowsVibrancy = allowsVibrancy
        return self
    }
}

class PaddedNSTextFieldCell: NSTextFieldCell {
    var widthPadding: CGFloat = 0
    var heightPadding: CGFloat = 0

    override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.width += (widthPadding * 2)
        size.height += (heightPadding * 2)
        return size
    }

    override func titleRect(forBounds rect: NSRect) -> NSRect {
        return rect.insetBy(dx: widthPadding, dy: heightPadding)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let rect = cellFrame.insetBy(dx: widthPadding, dy: heightPadding)
        super.drawInterior(withFrame: rect, in: controlView)
    }
}
