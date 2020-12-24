//
//  ProxyConfigRemoteProcessProtocol.h
//  com.west2online.ClashX.ProxyConfigHelper
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

@import Foundation;

typedef void(^stringReplyBlock)(NSString *);
typedef void(^boolReplyBlock)(BOOL);
typedef void(^dictReplyBlock)(NSDictionary *);

@protocol ProxyConfigRemoteProcessProtocol <NSObject>
@required

- (void)getVersion:(stringReplyBlock)reply;

- (void)enableProxyWithPort:(int)port
          socksPort:(int)socksPort
            pac:(NSString *)pac
            filterInterface:(BOOL)filterInterface
            error:(stringReplyBlock)reply;

- (void)disableProxyWithFilterInterface:(BOOL)filterInterface
                                  reply:(stringReplyBlock)reply;

- (void)restoreProxyWithCurrentPort:(int)port
                          socksPort:(int)socksPort
                               info:(NSDictionary *)dict
                    filterInterface:(BOOL)filterInterface
                              error:(stringReplyBlock)reply;

- (void)getCurrentProxySetting:(dictReplyBlock)reply;
@end
