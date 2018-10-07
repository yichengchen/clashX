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
        
        bridge.registerHandler("wirteConfigWithString") {(anydata, responseCallback) in
            if let str = anydata as? String {
                if (FileManager.default.fileExists(atPath: kConfigFilePath)) {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: kConfigFilePath))
                }
                try? str.write(to: URL(fileURLWithPath: kConfigFilePath), atomically: true, encoding: .utf8)
            }
        }
        
        bridge.registerHandler("setSystemProxy") {(anydata, responseCallback) in
            if let dict = anydata as? [String:Int] {
                let success = ProxyConfigManager.setUpSystemProxy(port: dict["port"], socksPort: dict["socksPort"])
                responseCallback?(success)
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
            }
        }

        bridge.registerHandler("getPasteboard") {(anydata, responseCallback) in
            let str = NSPasteboard.general.string(forType: NSPasteboard.PasteboardType.string)
            responseCallback?(str ?? "")
        }
        
        
        // ping-pong
        bridge.registerHandler("ping"){ (anydata, responseCallback) in
            bridge.callHandler("pong")
        }
        
        
        return bridge
    }
}
