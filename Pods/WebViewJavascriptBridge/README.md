WebViewJavascriptBridge
=======================

[![Circle CI](https://img.shields.io/circleci/project/github/marcuswestin/WebViewJavascriptBridge.svg)](https://circleci.com/gh/marcuswestin/WebViewJavascriptBridge)

An iOS/OSX bridge for sending messages between Obj-C and JavaScript in WKWebViews, UIWebViews & WebViews.

Migration Guide
---------------

When upgrading from v5.0.x to 6.0.x you will have to update the `setupWebViewJavascriptBridge` javascript snippet. See https://github.com/marcuswestin/WebViewJavascriptBridge#usage part 4).

Who uses WebViewJavascriptBridge?
---------------------------------
WebViewJavascriptBridge is used by a range of companies and projects. This is a small and incomplete sample list:

- [Facebook Messenger](https://www.facebook.com/mobile/messenger)
- [Facebook Paper](https://facebook.com/paper)
- [Yardsale](http://www.getyardsale.com/)
- [EverTrue](http://www.evertrue.com/)
- [Game Insight](http://www.game-insight.com/)
- [Sush.io](http://www.sush.io)
- [Imbed](http://imbed.github.io/)
- [CareZone](https://carezone.com)
- [Hemlig](http://www.hemlig.co)
- [Altralogica](http://www.altralogica.it)
- [鼎盛中华](https://itunes.apple.com/us/app/ding-sheng-zhong-hua/id537273940?mt=8)
- [FRIL](https://fril.jp)
- [留白·WHITE](http://liubaiapp.com)
- [BrowZine](http://thirdiron.com/browzine/)
- ... & many more!

Installation (iOS & OSX)
------------------------

### Installation with CocoaPods
Add this to your [podfile](https://guides.cocoapods.org/using/getting-started.html) and run `pod install` to install:

```ruby
pod 'WebViewJavascriptBridge'
```

### Manual installation

Drag the `WebViewJavascriptBridge` folder into your project.

In the dialog that appears, uncheck "Copy items into destination group's folder" and select "Create groups for any folders".

Examples
--------

See the `Example Apps/` folder. Open either the iOS or OSX project and hit run to see it in action.

To use a WebViewJavascriptBridge in your own project:

Usage
-----

1) Import the header file and declare an ivar property:

```objc
#import "WebViewJavascriptBridge.h"
```

...

```objc
@property WebViewJavascriptBridge* bridge;
```

2) Instantiate WebViewJavascriptBridge with a WKWebView, UIWebView (iOS) or WebView (OSX):

```objc
self.bridge = [WebViewJavascriptBridge bridgeForWebView:webView];
```

3) Register a handler in ObjC, and call a JS handler:

```objc
[self.bridge registerHandler:@"ObjC Echo" handler:^(id data, WVJBResponseCallback responseCallback) {
	NSLog(@"ObjC Echo called with: %@", data);
	responseCallback(data);
}];
[self.bridge callHandler:@"JS Echo" data:nil responseCallback:^(id responseData) {
	NSLog(@"ObjC received response: %@", responseData);
}];
```

4) Copy and paste `setupWebViewJavascriptBridge` into your JS:
	
```javascript
function setupWebViewJavascriptBridge(callback) {
	if (window.WebViewJavascriptBridge) { return callback(WebViewJavascriptBridge); }
	if (window.WVJBCallbacks) { return window.WVJBCallbacks.push(callback); }
	window.WVJBCallbacks = [callback];
	var WVJBIframe = document.createElement('iframe');
	WVJBIframe.style.display = 'none';
	WVJBIframe.src = 'https://__bridge_loaded__';
	document.documentElement.appendChild(WVJBIframe);
	setTimeout(function() { document.documentElement.removeChild(WVJBIframe) }, 0)
}
```

5) Finally, call `setupWebViewJavascriptBridge` and then use the bridge to register handlers and call ObjC handlers:

```javascript
setupWebViewJavascriptBridge(function(bridge) {
	
	/* Initialize your app here */

	bridge.registerHandler('JS Echo', function(data, responseCallback) {
		console.log("JS Echo called with:", data)
		responseCallback(data)
	})
	bridge.callHandler('ObjC Echo', {'key':'value'}, function responseCallback(responseData) {
		console.log("JS received response:", responseData)
	})
})
```

Automatic reference counting (ARC)
----------------------------------
This library relies on ARC, so if you use ARC in you project, all works fine.
But if your project have no ARC support, be sure to do next steps:

1) In your Xcode project open project settings -> 'Build Phases'

2) Expand 'Compile Sources' header and find all *.m files which are belongs to this library. Make attention on the 'Compiler Flags' in front of each source file in this list

3) For each file add '-fobjc-arc' flag

Now all WVJB files will be compiled with ARC support.

Contributors & Forks
--------------------
Contributors: https://github.com/marcuswestin/WebViewJavascriptBridge/graphs/contributors

Forks: https://github.com/marcuswestin/WebViewJavascriptBridge/network/members

API Reference
-------------

### ObjC API

##### `[WebViewJavascriptBridge bridgeForWebView:(WKWebVIew/UIWebView/WebView*)webview`

Create a javascript bridge for the given web view.

Example:

```objc	
[WebViewJavascriptBridge bridgeForWebView:webView];
```

##### `[bridge registerHandler:(NSString*)handlerName handler:(WVJBHandler)handler]`

Register a handler called `handlerName`. The javascript can then call this handler with `WebViewJavascriptBridge.callHandler("handlerName")`.

Example:

```objc
[self.bridge registerHandler:@"getScreenHeight" handler:^(id data, WVJBResponseCallback responseCallback) {
	responseCallback([NSNumber numberWithInt:[UIScreen mainScreen].bounds.size.height]);
}];
[self.bridge registerHandler:@"log" handler:^(id data, WVJBResponseCallback responseCallback) {
	NSLog(@"Log: %@", data);
}];

```

##### `[bridge callHandler:(NSString*)handlerName data:(id)data]`
##### `[bridge callHandler:(NSString*)handlerName data:(id)data responseCallback:(WVJBResponseCallback)callback]`

Call the javascript handler called `handlerName`. If a `responseCallback` block is given the javascript handler can respond.

Example:

```objc
[self.bridge callHandler:@"showAlert" data:@"Hi from ObjC to JS!"];
[self.bridge callHandler:@"getCurrentPageUrl" data:nil responseCallback:^(id responseData) {
	NSLog(@"Current UIWebView page URL is: %@", responseData);
}];
```

#### `[bridge setWebViewDelegate:(id)webViewDelegate]`

Optionally, set a `WKNavigationDelegate/UIWebViewDelegate` if you need to respond to the [web view's lifecycle events](https://developer.apple.com/reference/uikit/uiwebviewdelegate).

##### `[bridge disableJavscriptAlertBoxSafetyTimeout]`

UNSAFE. Speed up bridge message passing by disabling the setTimeout safety check. It is only safe to disable this safety check if you do not call any of the javascript popup box functions (alert, confirm, and prompt). If you call any of these functions from the bridged javascript code, the app will hang.

Example:

	[self.bridge disableJavscriptAlertBoxSafetyTimeout];



### Javascript API

##### `bridge.registerHandler("handlerName", function(responseData) { ... })`

Register a handler called `handlerName`. The ObjC can then call this handler with `[bridge callHandler:"handlerName" data:@"Foo"]` and `[bridge callHandler:"handlerName" data:@"Foo" responseCallback:^(id responseData) { ... }]`

Example:

```javascript
bridge.registerHandler("showAlert", function(data) { alert(data) })
bridge.registerHandler("getCurrentPageUrl", function(data, responseCallback) {
	responseCallback(document.location.toString())
})
```


##### `bridge.callHandler("handlerName", data)`
##### `bridge.callHandler("handlerName", data, function responseCallback(responseData) { ... })`

Call an ObjC handler called `handlerName`. If a `responseCallback` function is given the ObjC handler can respond.

Example:

```javascript
bridge.callHandler("Log", "Foo")
bridge.callHandler("getScreenHeight", null, function(response) {
	alert('Screen height:' + response)
})
```


##### `bridge.disableJavscriptAlertBoxSafetyTimeout()`

Calling `bridge.disableJavscriptAlertBoxSafetyTimeout()` has the same effect as calling `[bridge disableJavscriptAlertBoxSafetyTimeout];` in ObjC.

Example:

```javascript
bridge.disableJavscriptAlertBoxSafetyTimeout()
```
