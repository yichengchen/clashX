//
//  StatusItemView.swift
//  ClashX
//
//  Created by CYC on 2018/6/23.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Foundation
import AppKit
import RxCocoa
import RxSwift

class StatusItemView: NSView {
    
    @IBOutlet var imageView: NSImageView!
    
    @IBOutlet var uploadSpeedLabel: NSTextField!
    @IBOutlet var downloadSpeedLabel: NSTextField!
    @IBOutlet weak var speedContainerView: NSView!
    weak var statusItem:NSStatusItem?
    var disposeBag = DisposeBag()
    var isDarkMode = false
    
    var onPopUpMenuAction:(()->())? = nil
    
    static func create(statusItem:NSStatusItem?,statusMenu:NSMenu)->StatusItemView{
        var topLevelObjects : NSArray?
        if Bundle.main.loadNibNamed("StatusItemView", owner: self, topLevelObjects: &topLevelObjects) {
            let view = (topLevelObjects!.first(where: { $0 is NSView }) as? StatusItemView)!
            view.statusItem = statusItem
            view.menu = statusMenu
            view.setupView()
            statusMenu.delegate = view
            return view
        }
        return NSView() as! StatusItemView
    }
    
    func setupView() {
        let darkModeObservable = UserDefaults.standard
            .rx.observe(String.self, "AppleInterfaceStyle").map { $0 as AnyObject };
        let proxySetObservable = ConfigManager.shared.proxyPortAutoSetObservable.map { $0 as AnyObject }
        Observable
            .of(darkModeObservable,proxySetObservable)
            .merge()
            .bind { [weak self] _ in
                guard let self = self else {return}
                let darkMode =
                    UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light" == "Dark"
                let enableProxy = ConfigManager.shared.proxyPortAutoSet;
                
                let customImagePath = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash/menuImage.png")
                
                let selectedColor = darkMode ? NSColor.white : NSColor.black
                let unselectedColor = NSColor.gray
                let image = NSImage(contentsOfFile: customImagePath) ??
                    NSImage(named: "menu_icon")!.tint(color: enableProxy ? selectedColor : unselectedColor)
                
                self.imageView.image = image
                
                self.uploadSpeedLabel.textColor = darkMode ? NSColor.white : NSColor.black
                self.downloadSpeedLabel.textColor = self.uploadSpeedLabel.textColor
                self.isDarkMode = darkMode
                
        }.disposed(by: disposeBag)
        

    }
    
    func updateSpeedLabel(up:Int,down:Int) {
        let kbup = up/1024
        let kbdown = down/1024
        var finalUpStr:String
        var finalDownStr:String
        if kbup < 1024 {
            finalUpStr = "\(kbup)KB/s"
        } else {
            finalUpStr = String(format: "%.2fMB/s", (Double(kbup)/1024.0))
        }
        
        if kbdown < 1024 {
            finalDownStr = "\(kbdown)KB/s"
        } else {
            finalDownStr = String(format: "%.2fMB/s", (Double(kbdown)/1024.0))
        }
        DispatchQueue.main.async {
            self.downloadSpeedLabel.stringValue = finalDownStr
            self.uploadSpeedLabel.stringValue = finalUpStr
        }
   
    }
    
    func showSpeedContainer(show:Bool) {
        self.speedContainerView.isHidden = !show
    }
    
    override func mouseDown(with event: NSEvent) {
        onPopUpMenuAction?()
        statusItem?.popUpMenu(self.menu!)
    }
}

extension StatusItemView:NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        drawHighlight(highlight: true)

    }
    
    func menuDidClose(_ menu: NSMenu) {
        drawHighlight(highlight: false)
    }
    
    
    func drawHighlight(highlight:Bool) {
        let image = NSImage(size: self.frame.size)
        image.lockFocus()
        statusItem?.drawStatusBarBackground(in: self.bounds, withHighlight: highlight)
        image.unlockFocus()
        self.layer?.contents = image
        
        if !self.isDarkMode {
            self.uploadSpeedLabel.textColor = highlight ? NSColor.white : NSColor.black
            self.downloadSpeedLabel.textColor = highlight ? NSColor.white : NSColor.black
        }
    }
}
