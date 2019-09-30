//
//  AboutViewController.swift
//  ClashX
//
//  Created by CYC on 2018/8/19.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa

class AboutViewController: NSViewController {

    @IBOutlet weak var versionLabel: NSTextField!
    @IBOutlet weak var buildTimeLabel: NSTextField!
    @IBOutlet weak var coreVersionLabel: NSTextField!
    
    lazy var compileDate: Date = {
        let bundleName = Bundle.main.infoDictionary!["CFBundleName"] as? String ?? "Info.plist"
        if let infoPath = Bundle.main.path(forResource: bundleName, ofType: nil),
            let infoAttr = try? FileManager.default.attributesOfItem(atPath: infoPath),
            let infoDate = infoAttr[FileAttributeKey.creationDate] as? Date {
            return infoDate
        }
        return Date()
    }()
    
    lazy var clashCoreVersion: String = {
        return Bundle.main.infoDictionary?["coreVersion"] as? String ?? "unknown"
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "About"
        
        let version = AppVersionUtil.currentVersion
        let build = AppVersionUtil.currentBuild
        
        versionLabel.stringValue = "Version: \(version) (\(build))"
        coreVersionLabel.stringValue = clashCoreVersion
        buildTimeLabel.stringValue = self.compileDate.description

    }
    
    override func viewWillAppear() {
        super .viewWillAppear()
        NSApp.activate(ignoringOtherApps: true)
        self.view.window?.styleMask.remove(.resizable)
        self.view.window?.makeKeyAndOrderFront(self)
    }
    
}


@IBDesignable
class HyperlinkTextField: NSTextField {
    
    @IBInspectable var href: String = ""
    
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(self.bounds, cursor: NSCursor.pointingHand)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        // TODO:  Fix this and get the hover click to work.
        
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.foregroundColor: NSColor.blue,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue as AnyObject
        ]
        attributedStringValue = NSAttributedString(string: self.stringValue, attributes: attributes)
    }
    
    override func mouseDown(with theEvent: NSEvent) {
        if let localHref = URL(string: href) {
            NSWorkspace.shared.open(localHref)
        }
    }
}
