//
//  ProxyMenuItemFactory.swift
//  ClashX
//
//  Created by CYC on 2018/8/4.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import SwiftyJSON
import RxCocoa

class ProxyMenuItemFactory {
    static func menuItems(completionHandler:@escaping (([NSMenuItem])->())){
        ApiRequest.requestProxyGroupList { (res) in
            let dataDict = JSON(res)
            var menuItems = [NSMenuItem]()
            if (ConfigManager.shared.currentConfig?.mode == .direct) {
                completionHandler(menuItems)
                return
            }
            for proxyGroup in dataDict.dictionaryValue.sorted(by: {  $0.0 < $1.0}) {
                var menu:NSMenuItem?
                switch proxyGroup.value["type"].stringValue {
                case "Selector": menu = self.generateSelectorMenuItem(json: dataDict, key: proxyGroup.key)
                case "URLTest","Fallback": menu = self.generateUrlTestMenuItem(proxyGroup: proxyGroup)
                default: continue
                }
                if (menu != nil) {menuItems.append(menu!)}
                
            }
            completionHandler(menuItems.reversed())
        }
    }
    
    static func generateSelectorMenuItem(json:JSON,key:String)->NSMenuItem? {
        let proxyGroup:(key: String, value: JSON) = (key,json[key])
        let isGlobalMode = ConfigManager.shared.currentConfig?.mode == .global
        if (isGlobalMode) {
            if proxyGroup.key != "GLOBAL" {return nil}
        } else {
            if proxyGroup.key == "GLOBAL" {return nil}
        }
        
        let menu = NSMenuItem(title: proxyGroup.key, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.value["now"].stringValue
        let submenu = NSMenu(title: proxyGroup.key)
        var hasSelected = false
        submenu.minimumWidth = 20
        for proxy in proxyGroup.value["all"].arrayValue {
            if isGlobalMode {
                if json[proxy.stringValue]["type"] == "Selector" {
                    continue
                }
            }
            
            let proxyItem = NSMenuItem(title: proxy.stringValue, action: #selector(ProxyMenuItemFactory.actionSelectProxy(sender:)), keyEquivalent: "")
            proxyItem.target = ProxyMenuItemFactory.self
            
            let delay = SpeedDataRecorder.shared.speedDict[proxy.stringValue]
            
            let selected = proxy.stringValue == selectedName
            proxyItem.state = selected ? .on : .off
            let menuItemView = ProxyMenuItemView.create(proxy: proxy.stringValue, delay: delay)
            menuItemView.isSelected = selected
            menuItemView.onClick = { [weak proxyItem] in
                guard let proxyItem = proxyItem else {return}
                ProxyMenuItemFactory.actionSelectProxy(sender: proxyItem)
            }
            proxyItem.view = menuItemView
            if selected {hasSelected = true}
            submenu.addItem(proxyItem)
            submenu.autoenablesItems = false
            let fittitingWidth = menuItemView.fittingSize.width
            if (fittitingWidth > submenu.minimumWidth) {
                submenu.minimumWidth = fittitingWidth
            }
        }
        for item in submenu.items {
            item.view?.frame.size.width = submenu.minimumWidth
        }
        menu.submenu = submenu
        if (!hasSelected && submenu.items.count>0) {
            self.actionSelectProxy(sender: submenu.items[0])
        }
        return menu
    }
    
    static func generateUrlTestMenuItem(proxyGroup:(key: String, value: JSON))->NSMenuItem? {
        
        let menu = NSMenuItem(title: proxyGroup.key, action: nil, keyEquivalent: "")
        let selectedName = proxyGroup.value["now"].stringValue
        let submenu = NSMenu(title: proxyGroup.key)

        let nowMenuItem = NSMenuItem(title: "now:\(selectedName)", action: nil, keyEquivalent: "")
        
        submenu.addItem(nowMenuItem)
        menu.submenu = submenu
        return menu
    }
    
    @objc static func actionSelectProxy(sender:NSMenuItem){
        guard let proxyGroup = sender.menu?.title else {return}
        let proxyName = sender.title
        
        ApiRequest.updateProxyGroup(group: proxyGroup, selectProxy: proxyName) { (success) in
            if (success) {
                for items in sender.menu?.items ?? [NSMenuItem]() {
                    items.state = .off
                }
                sender.state = .on
                // remember select proxy
                ConfigManager.selectedProxyMap[proxyGroup] = proxyName
            }
        }
    }
    
    
}

