//
//  ProxySettingTool.h
//  com.west2online.ClashX.ProxyConfigHelper
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ProxySettingTool : NSObject

- (void)enableProxyWithport:(int)port socksPort:(int)socksPort
                     pacUrl:(NSString *)pacUrl
            filterInterface:(BOOL)filterInterFace;
- (void)disableProxyWithfilterInterface:(BOOL)filterInterFace;

- (void)restoreProxySettint:(NSDictionary *)savedInfo
                currentPort:(int)port
           currentSocksPort:(int)socksPort
            filterInterface:(BOOL)filterInterface;
+ (NSMutableDictionary<NSString *,NSDictionary *> *)currentProxySettings;

@end

NS_ASSUME_NONNULL_END
