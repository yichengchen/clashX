//
//  CommonUtils.h
//  ClashX
//
//  Created by yicheng on 2020/4/2.
//  Copyright © 2020 west2online. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonUtils : NSObject
+ (NSString *)runCommand:(NSString *)path args:(nullable NSArray *)args;
@end

NS_ASSUME_NONNULL_END
