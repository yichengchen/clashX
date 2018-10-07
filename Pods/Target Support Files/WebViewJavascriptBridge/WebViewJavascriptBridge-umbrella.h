#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "WebViewJavascriptBridge.h"
#import "WebViewJavascriptBridgeBase.h"
#import "WKWebViewJavascriptBridge.h"

FOUNDATION_EXPORT double WebViewJavascriptBridgeVersionNumber;
FOUNDATION_EXPORT const unsigned char WebViewJavascriptBridgeVersionString[];

