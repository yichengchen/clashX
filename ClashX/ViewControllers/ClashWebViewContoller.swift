//
//  ClashWebViewContoller.swift
//  ClashX
//
//  Created by CYC on 2018/8/28.
//  Copyright © 2018年 west2online. All rights reserved.
//

import Cocoa
import WebKit
import WebViewJavascriptBridge
import RxSwift
import RxCocoa

class ClashWebViewContoller: NSViewController {
    let webview: CustomWKWebView = CustomWKWebView()
    var bridge:WebViewJavascriptBridge?
    var disposeBag = DisposeBag()
    
    @IBOutlet weak var effectView: NSVisualEffectView!
    
    static func enableDashBoard() -> Bool {
        return UserDefaults.standard.bool(forKey: "kEnableDashboard")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webview.uiDelegate = self
        webview.navigationDelegate = self

        if #available(OSX 10.11, *) {
            webview.customUserAgent = "ClashX Runtime"
        } else {
//             Fallback on earlier versions
        }
        if NSAppKitVersion.current.rawValue > 1500 {
            webview.setValue(false, forKey: "drawsBackground")
        } else {
            webview.setValue(true, forKey: "drawsTransparentBackground")
        }
        view.addSubview(webview)


        webview.translatesAutoresizingMaskIntoConstraints = false
        let attributes:[NSLayoutConstraint.Attribute] = [.top,.left,.bottom,.right,.top]
        for attribute in attributes {

            let constraint = NSLayoutConstraint(item: webview,
                                                attribute: attribute,
                                                relatedBy: .equal,
                                                toItem: view,
                                                attribute: attribute ,
                                                multiplier: 1, constant: 0);
            constraint.priority = NSLayoutConstraint.Priority(rawValue: 100);
            view.addConstraint(constraint)
        }

        bridge = JsBridgeHelper.initJSbridge(webview: webview, delegate: self)
        registerExtenalJSBridgeFunction()

        webview.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        NotificationCenter.default.rx.notification(kConfigFileChange).bind {
            [weak self] (note)  in
            self?.bridge?.callHandler("onConfigChange")
            }.disposed(by: disposeBag)

        // defaults write com.west2online.ClashX webviewUrl "your url"
        let url = UserDefaults.standard.string(forKey: "webviewUrl") ?? "http://127.0.0.1:8080"
        self.webview.load(URLRequest(url: URL(string: url)!))
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.titleVisibility = .hidden
        view.window?.titlebarAppearsTransparent = true
        view.window?.styleMask.insert(.fullSizeContentView)

        NSApp.activate(ignoringOtherApps: true)
        view.window?.makeKeyAndOrderFront(self)
        
        view.window?.isOpaque = false
        view.window?.backgroundColor = NSColor.clear
        view.window?.styleMask.remove(.resizable)
        view.window?.styleMask.remove(.miniaturizable)
    }
    
}

extension ClashWebViewContoller {
    func registerExtenalJSBridgeFunction(){
        self.bridge?.registerHandler("setDragAreaHeight") {(anydata, responseCallback) in
            if let height = anydata as? CGFloat {
                self.webview.dragableAreaHeight = height;
            }
            responseCallback?(nil)
        }
    }
}

extension ClashWebViewContoller:WKUIDelegate,WKNavigationDelegate {
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Logger.log(msg: "\(String(describing: navigation))", level: .debug)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.log(msg: "\(error)", level: .debug)
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if (navigationAction.targetFrame == nil){
            webView.load(navigationAction.request)
        }
        return nil;
    }
    
}


class CustomWKWebView: WKWebView {
    
    var dragableAreaHeight:CGFloat = 20;
    let alwaysDragableLeftAreaWidth:CGFloat = 150;
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let x = event.locationInWindow.x
        let y = (self.window?.frame.size.height ?? 0) - event.locationInWindow.y
        
        if x < alwaysDragableLeftAreaWidth || y < dragableAreaHeight {
            if #available(OSX 10.11, *) {
                self.window?.performDrag(with: event)
            }
        }
    }
}
