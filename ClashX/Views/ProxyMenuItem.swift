//
//  ProxyMenuItem.swift
//  ClashX
//
//  Created by CYC on 2019/2/18.
//  Copyright © 2019 west2online. All rights reserved.
//

import Cocoa

class ProxyMenuItem:NSMenuItem {
    var proxyName:String = ""
    
    init(proxyName string: String, action selector: Selector?) {
        super.init(title: string, action: selector, keyEquivalent: "")
        
	proxyName = string
        if let delay = SpeedDataRecorder.shared.getDelay(string) {
            let menuItemView = ProxyMenuItemView.create(proxy: string, delay: delay)
            menuItemView.onClick = { [weak self] in
                guard let self = self else {return}
                MenuItemFactory.actionSelectProxy(sender: self)
            }
            self.view = menuItemView
        }
        
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isSelected:Bool = false {
        didSet {
            self.state = isSelected ? .on : .off
            (self.view as? ProxyMenuItemView)?.isSelected = isSelected
        }
    }
    
    func suggestWidth()->CGFloat {
        return self.view?.fittingSize.width ?? 0
    }
    

}

