//
//  SPUDownloader.h
//  Downloader
//
//  Created by Mayur Pawashe on 4/1/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif
#import "SPUDownloaderProtocol.h"

@protocol SPUDownloaderDelegate;

// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
@interface SPUDownloader : NSObject <SPUDownloaderProtocol>

// Due to XPC remote object reasons, this delegate is strongly referenced
// Invoke cleanup when done with this instance
- (instancetype)initWithDelegate:(id <SPUDownloaderDelegate>)delegate;

@end
