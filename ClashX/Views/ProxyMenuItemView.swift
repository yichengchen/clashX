//
//  ProxyMenuItemView.swift
//  
//
//  Created by CYC on 2018/10/19.
//

import Cocoa

class ProxyMenuItemView: NSView {
    static func create(proxy:String,delay:Int?)->ProxyMenuItemView {
        var topLevelObjects : NSArray?
        if Bundle.main.loadNibNamed("ProxyMenuItemView", owner: self, topLevelObjects: &topLevelObjects) {
            let view = (topLevelObjects!.first(where: { $0 is NSView }) as? ProxyMenuItemView)!
            view.proxyNameLabel.stringValue = proxy
            return view;
        }
        return NSView() as! ProxyMenuItemView
    }
    
    @IBOutlet weak var proxyNameLabel: NSTextField!
    
    @IBOutlet weak var delayLabel: NSTextField!
    
    var highlighted : Bool = false {
        didSet {
            if oldValue != highlighted {
                needsDisplay = true
            }
        }
    }
    
    
   
    
    override func draw(_ dirtyRect: NSRect) {
        if highlighted && enclosingMenuItem!.isHighlighted {
            NSColor.selectedMenuItemColor.set()
            self.proxyNameLabel.textColor = NSColor.white
            self.delayLabel.textColor = NSColor.white
        } else {
            NSColor.clear.set()
            self.proxyNameLabel.textColor = NSColor.labelColor
            self.delayLabel.textColor = NSColor.labelColor
        }
        NSBezierPath.fill(dirtyRect)
        super.draw(dirtyRect)
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        let trackingArea = NSTrackingArea(rect: self.bounds, options: [.mouseEnteredAndExited,.activeAlways], owner: self, userInfo: nil);
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with theEvent: NSEvent) {
        super.mouseEntered(with: theEvent)
        highlighted = true
        
    }
    override func mouseExited(with theEvent: NSEvent) {
        super.mouseExited(with: theEvent)
        highlighted = false
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        print("11")
    }
}
