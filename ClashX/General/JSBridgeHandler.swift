//
//  JSBridgeHandler.swift
//  ClashX
//
//  Created by CYC on 2018/8/29.
//  Copyright © 2018年 west2online. All rights reserved.
//


import WebViewJavascriptBridge
import SwiftyJSON
import Alamofire

class JsBridgeHelper {
    static func initJSbridge(webview:Any,delegate:Any) -> WebViewJavascriptBridge {
        let bridge = WebViewJavascriptBridge(webview)!
        
        bridge.setWebViewDelegate(delegate)
        
        // 文件存储
        bridge.registerHandler("readConfigString") {(anydata, responseCallback) in
            let configData = NSData(contentsOfFile: kConfigFilePath) ?? NSData()
            let configStr = String(data: configData as Data, encoding: .utf8) ?? ""
            responseCallback?(configStr)
        }
        
        bridge.registerHandler("writeConfigWithString") {(anydata, responseCallback) in
            do {
                if let str = anydata as? String {
                    if (FileManager.default.fileExists(atPath: kConfigFilePath)) {
                        try? FileManager.default.removeItem(at: URL(fileURLWithPath: kConfigFilePath))
                    }
                    try str.write(to: URL(fileURLWithPath: kConfigFilePath), atomically: true, encoding: .utf8)
                } else {
                    responseCallback?(false)
                }
            } catch {
                responseCallback?(false)
            }
        }
        
        bridge.registerHandler("isSystemProxySet") {(anydata, responseCallback) in
            responseCallback?(ConfigManager.shared.proxyPortAutoSet)
        }
        
        bridge.registerHandler("setSystemProxy") {(anydata, responseCallback) in
            if let enable = anydata as? Bool {
                ConfigManager.shared.proxyPortAutoSet = enable
                if let config = ConfigManager.shared.currentConfig {
                    let success:Bool
                    if enable{
                        success = ProxyConfigManager.setUpSystemProxy(port:  config.port,socksPort: config.socketPort)
                    } else {
                        success = ProxyConfigManager.setUpSystemProxy(port:  nil,socksPort: nil)
                    }
                    responseCallback?(success)
                } else {
                    responseCallback?(false)
                }
            } else {
                responseCallback?(false)
            }
        }
        
        bridge.registerHandler("QRcodesFromScreen") {(anydata, responseCallback) in
            let urls = QRCodeUtil.ScanQRCodeOnScreen()
            responseCallback?(urls)
        }
   
        
        // 剪贴板
        bridge.registerHandler("setPasteboard") {(anydata, responseCallback) in
            if let str = anydata as? String {
                NSPasteboard.general.setString(str, forType: .string)
                responseCallback?(true)
            } else {
                responseCallback?(false)
            }
        }

        bridge.registerHandler("getPasteboard") {(anydata, responseCallback) in
            let str = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string)
            responseCallback?(str ?? "")
        }
        
        bridge.registerHandler("getStartAtLogin") { (_, responseCallback) in
            responseCallback?(LaunchAtLogin.shared.isEnabled)
        }
        
        bridge.registerHandler("setStartAtLogin") { (anydata, responseCallback) in
            if let enable = anydata as? Bool {
                LaunchAtLogin.shared.isEnabled = enable
                responseCallback?(true)
            } else {
                responseCallback?(false)
            }
        }
        
        bridge.registerHandler("speedTest") { (anydata, responseCallback) in
            if let proxyName = anydata as? String {
                ApiRequest.getProxyDelay(proxyName: proxyName) { (delay) in
                    SpeedDataRecorder.shared.speedDict[proxyName] = delay
                    responseCallback?(delay)
                }
            } else {
                responseCallback?(nil)
            }
        }
        
        
        // ping-pong
        bridge.registerHandler("ping"){ (anydata, responseCallback) in
            bridge.callHandler("pong")
            responseCallback?(true)
        }
        return bridge
    }
}
