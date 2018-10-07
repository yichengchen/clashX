/**
 * Network Change Notifier
 *
 * Made by François 'ftiff' Levaux-Tiffreau - fti@me.com
 *
 *
 * Simply modify "changed"
 *
 */

import Cocoa
import SystemConfiguration
import Foundation

class NetworkChangeNotifier {
    static func start(){
        let changed: SCDynamicStoreCallBack = {_,_,_ in
            print("Network configuration changed")
            NotificationCenter.default.post(name: kSystemNetworkStatusDidChange, object: nil)
        }
        
        var dynamicContext = SCDynamicStoreContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        let dcAddress = withUnsafeMutablePointer(to:&dynamicContext, {UnsafeMutablePointer<SCDynamicStoreContext>($0)})
        
        if let dynamicStore = SCDynamicStoreCreate(kCFAllocatorDefault, "io.fti.networkconfigurationchanged" as CFString, changed, dcAddress){
            let keys: [CFString] = ["State:/Network/Global/IPv4" as CFString]

            SCDynamicStoreSetNotificationKeys(dynamicStore, keys as CFArray, nil)
            
            let loop = SCDynamicStoreCreateRunLoopSource(kCFAllocatorDefault, dynamicStore, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, CFRunLoopMode.defaultMode)
            
            CFRunLoopRun()
        }
    }
    
    static func currentSystemProxySetting() -> (UInt,UInt,UInt) {
        let proxiesSetting = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as! [String:AnyObject]
        let httpProxy = proxiesSetting[kCFNetworkProxiesHTTPPort as String] as? UInt ?? 0
        let socksProxy = proxiesSetting[kCFNetworkProxiesSOCKSPort as String]as? UInt ?? 0
        let httpsProxy = proxiesSetting[kCFNetworkProxiesHTTPSPort as String]as? UInt ?? 0
        return (httpProxy,httpsProxy,socksProxy)
    }
}

