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
    
    
    static func create(statusItem:NSStatusItem?)->StatusItemView{
        var topLevelObjects : NSArray?
        if Bundle.main.loadNibNamed("StatusItemView", owner: self, topLevelObjects: &topLevelObjects) {
            let view = (topLevelObjects!.first(where: { $0 is NSView }) as? StatusItemView)!
            view.statusItem = statusItem
            view.setupView()
            return view
        }
        return NSView() as! StatusItemView
    }
    
    func setupView() {
        let proxySetObservable = ConfigManager.shared.proxyPortAutoSetObservable.map { $0 as AnyObject }
        proxySetObservable
            .bind { [weak self] _ in
                guard let self = self else {return}
                let enableProxy = ConfigManager.shared.proxyPortAutoSet;
                
                let customImagePath = (NSHomeDirectory() as NSString).appendingPathComponent("/.config/clash/menuImage.png")
                
                let selectedColor = NSColor.red
                let unselectedColor: NSColor
                if #available(OSX 10.14, *) {
                    unselectedColor = selectedColor.withSystemEffect(.disabled)
                } else {
                    unselectedColor = selectedColor.withAlphaComponent(0.5)
                }
                
                let image = NSImage(contentsOfFile: customImagePath) ??
                    NSImage(named: "menu_icon")!.tint(color: enableProxy ? selectedColor : unselectedColor)
                
                self.imageView.image = image
                
                self.uploadSpeedLabel.textColor = NSColor.black
                self.downloadSpeedLabel.textColor = self.uploadSpeedLabel.textColor
                
                self.updateStatusItemView()
        }.disposed(by: disposeBag)
    }
    
    func updateSpeedLabel(up:Int,down:Int) {
        guard !self.speedContainerView.isHidden else {return}
        
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
        
        updateStatusItemView()
   
    }
    
    func showSpeedContainer(show:Bool) {
        self.speedContainerView.isHidden = !show
        updateStatusItemView()
    }
    
    func updateStatusItemView() {
        statusItem?.updateImage(withView: self)
    }
}


extension NSStatusItem {
    func updateImage(withView: NSView) {
        image = NSImage(data: withView.dataWithPDF(inside: withView.bounds))
        image?.isTemplate = true
    }
}
