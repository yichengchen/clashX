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
        for proxy in proxyGroup.value["all"].arrayValue {
            if isGlobalMode {
                if json[proxy.stringValue]["type"] == "Selector" {
                    continue
                }
            }
            var speedText = ""
            let placeHolder = "\t"
            if let speedInfo = SpeedDataRecorder.shared.speedDict[proxy.stringValue] {
                speedText = speedInfo < Int.max ?"\(placeHolder)\(speedInfo) ms" : "\(placeHolder)fail"
            }
            
            let proxyItem = ProxyMenuItem(title: proxy.stringValue + speedText, action: #selector(ProxyMenuItemFactory.actionSelectProxy(sender:)), keyEquivalent: "")
            proxyItem.proxyName = proxy.stringValue
            proxyItem.target = ProxyMenuItemFactory.self
            let selected = proxy.stringValue == selectedName
            proxyItem.state = selected ? .on : .off
            if selected {hasSelected = true}
            submenu.addItem(proxyItem)
        }
        menu.submenu = submenu
        
        if (!hasSelected && submenu.items.count>0) {
            self.actionSelectProxy(sender: submenu.items[0] as! ProxyMenuItem)
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
    
    @objc static func actionSelectProxy(sender:ProxyMenuItem){
        guard let proxyGroup = sender.menu?.title else {return}
        let proxyName = sender.proxyName
        
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

class ProxyMenuItem:NSMenuItem {
    var proxyName:String = ""
}
