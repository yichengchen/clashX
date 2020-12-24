//
//  JSBridgeHandler.swift
//  ClashX
//
//  Created by CYC on 2018/8/29.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Alamofire
import SwiftyJSON
import WebViewJavascriptBridge

class JsBridgeUtil {
    static func initJSbridge(webview: Any, delegate: Any) -> WebViewJavascriptBridge {
        let bridge = WebViewJavascriptBridge(webview)!

        bridge.setWebViewDelegate(delegate)

        bridge.registerHandler("isSystemProxySet") { anydata, responseCallback in
            responseCallback?(ConfigManager.shared.proxyPortAutoSet)
        }

        bridge.registerHandler("setSystemProxy") { anydata, responseCallback in
            if let enable = anydata as? Bool {
                ConfigManager.shared.proxyPortAutoSet = enable
                if enable {
                    SystemProxyManager.shared.saveProxy()
                    SystemProxyManager.shared.enableProxy()
                } else {
                    SystemProxyManager.shared.disableProxy()
                }
                responseCallback?(true)
            } else {
                responseCallback?(false)
            }
        }

        bridge.registerHandler("getStartAtLogin") { _, responseCallback in
            responseCallback?(LaunchAtLogin.shared.isEnabled)
        }

        bridge.registerHandler("setStartAtLogin") { anydata, responseCallback in
            if let enable = anydata as? Bool {
                LaunchAtLogin.shared.isEnabled = enable
                responseCallback?(true)
            } else {
                responseCallback?(false)
            }
        }

        bridge.registerHandler("getBreakConnections") { _, responseCallback in
            responseCallback?(ConnectionManager.enableAutoClose)
        }

        bridge.registerHandler("setBreakConnections") { anydata, responseCallback in
            if let enable = anydata as? Bool {
                ConnectionManager.enableAutoClose = enable
                ConnectionManager.updateMenuItemStatus()
                responseCallback?(true)
            } else {
                responseCallback?(false)
            }
        }

        bridge.registerHandler("speedTest") { anydata, responseCallback in
            if let proxyName = anydata as? String {
                ApiRequest.getProxyDelay(proxyName: proxyName) { delay in
                    var resp: Int
                    if delay == Int.max {
                        resp = 0
                    } else {
                        resp = delay
                    }
                    responseCallback?(resp)
                }
            } else {
                responseCallback?(nil)
            }
        }

        bridge.registerHandler("apiInfo") { _, callback in
            var host = "127.0.0.1"
            var port = ConfigManager.shared.apiPort
            if let override = ConfigManager.shared.overrideApiURL,
                let overridedHost = override.host {
                host = overridedHost
                port = "\(override.port ?? 80)"
            }
            let data = [
                "host": host,
                "port": port,
                "secret": ConfigManager.shared.overrideSecret ?? ConfigManager.shared.apiSecret,
            ]
            callback?(data)
        }

        // ping-pong
        bridge.registerHandler("ping") { [weak bridge] anydata, responseCallback in
            bridge?.callHandler("pong")
            responseCallback?(true)
        }
        return bridge
    }
}
