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
            view.setupView(proxy:proxy,delay:delay)
            return view;
        }
        return NSView() as! ProxyMenuItemView
    }
    
    var onClick:(()->())? = nil
    
    @IBOutlet weak var proxyNameLabel: NSTextField!

    
    @IBOutlet weak var selectedImageView: NSImageView!
    @IBOutlet weak var delayLabel: NSTextField!
    
    var highlighted : Bool = false {
        didSet {
            if oldValue != highlighted {
                needsDisplay = true
            }
        }
    }
    
    var isSelected:Bool = false {
        didSet {
            self.selectedImageView.isHidden = !isSelected
        }
    }
    
    func setupView(proxy:String,delay:Int?){
        selectedImageView.image = NSImage(imageLiteralResourceName: NSImage.menuOnStateTemplateName)
        
        proxyNameLabel.stringValue = proxy
        if let delay = delay {
            switch delay {
            case Int.max:delayLabel.stringValue = "Fail"
            case ..<0:delayLabel.stringValue = "Unknown"
            default:delayLabel.stringValue = "\(delay)ms"
            }
        } else {
            delayLabel.isHidden = true
        }
    }
   
    
    override func draw(_ dirtyRect: NSRect) {
        if highlighted && enclosingMenuItem!.isHighlighted {
            NSColor.selectedMenuItemColor.set()
            self.proxyNameLabel.textColor = NSColor.white
            self.delayLabel.textColor = NSColor.white
            selectedImageView.image = selectedImageView.image?.tint(color: .white)
        } else {
            NSColor.clear.set()
            self.proxyNameLabel.textColor = NSColor.labelColor
            self.delayLabel.textColor = NSColor.labelColor
            selectedImageView.image = selectedImageView.image?.tint(color: .labelColor)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.enclosingMenuItem?.menu?.cancelTracking()
        }
        onClick?()
    }
}
