//
//  SPUDownloaderDelegate.h
//  Sparkle
//
//  Created by Mayur Pawashe on 4/1/16.
//  Copyright © 2016 Sparkle Project. All rights reserved.
//

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@class SPUDownloadData;

@protocol SPUDownloaderDelegate <NSObject>

// This is only invoked for persistent downloads
- (void)downloaderDidSetDestinationName:(NSString *)destinationName temporaryDirectory:(NSString *)temporaryDirectory;

// Under rare cases, this may be called more than once, in which case the current progress should be reset back to 0
// This is only invoked for persistent downloads
- (void)downloaderDidReceiveExpectedContentLength:(int64_t)expectedContentLength;

// This is only invoked for persistent downloads
- (void)downloaderDidReceiveDataOfLength:(uint64_t)length;

// downloadData is nil if this is a persisent download, otherwise it's non-nil if it's a temporary download
- (void)downloaderDidFinishWithTemporaryDownloadData:(SPUDownloadData * _Nullable)downloadData;

- (void)downloaderDidFailWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
