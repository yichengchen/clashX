//
//  SUAppcast.h
//  Sparkle
//
//  Created by Andy Matuschak on 3/12/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#ifndef SUAPPCAST_H
#define SUAPPCAST_H

#if __has_feature(modules)
@import Foundation;
#else
#import <Foundation/Foundation.h>
#endif
#import "SUExport.h"

NS_ASSUME_NONNULL_BEGIN

@class SUAppcastItem;
SU_EXPORT @interface SUAppcast : NSObject

@property (copy, nullable) NSString *userAgentString;
@property (copy, nullable) NSDictionary<NSString *, NSString *> *httpHeaders;

- (void)fetchAppcastFromURL:(NSURL *)url inBackground:(BOOL)bg completionBlock:(void (^)(NSError *_Nullable))err;
- (SUAppcast *)copyWithoutDeltaUpdates;

@property (readonly, copy, nullable) NSArray *items;
@end

NS_ASSUME_NONNULL_END

#endif
