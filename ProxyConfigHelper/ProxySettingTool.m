//
//  ProxySettingTool.m
//  com.west2online.ClashX.ProxyConfigHelper
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

#import "ProxySettingTool.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <AppKit/AppKit.h>
#import "CommonUtils.h"

@interface ProxySettingTool()
@property (nonatomic, assign) AuthorizationRef authRef;

@end

@implementation ProxySettingTool

- (instancetype)init {
    if (self = [super init]) {
        [self localAuth];
    }
    return self;
}

// MARK: - Public

- (void)enableProxyWithport:(int)port socksPort:(int)socksPort
                     pacUrl:(NSString *)pacUrl
            filterInterface:(BOOL)filterInterface  {

    [self applySCNetworkSettingWithRef:^(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:filterInterface devices:^(NSString *key, NSDictionary *dict) {
            [self enableProxySettings:ref interface:key port:port socksPort:socksPort pac:pacUrl];
        }];
    }];
}

- (void)disableProxyWithfilterInterface:(BOOL)filterInterface {
    [self applySCNetworkSettingWithRef:^(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:filterInterface devices:^(NSString *key, NSDictionary *dict) {
            [self disableProxySetting:ref interface:key];
        }];
    }];
}

- (void)restoreProxySettint:(NSDictionary *)savedInfo
                currentPort:(int)port
           currentSocksPort:(int)socksPort
            filterInterface:(BOOL)filterInterface{
    [self applySCNetworkSettingWithRef:^(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:filterInterface devices:^(NSString *key, NSDictionary *dict) {
            NSDictionary *proxySetting = savedInfo[key];
            if (![proxySetting isKindOfClass:[NSDictionary class]]) {
                proxySetting = nil;
            }
            
            if (!proxySetting) {
                [self disableProxySetting:ref interface:key];
                return;
            }
            
            int savedHttpPort = ((NSNumber *)(proxySetting[(__bridge NSString *)kCFNetworkProxiesHTTPPort])).intValue;
            int savedHttpsPort = ((NSNumber *)(proxySetting[(__bridge NSString *)kCFNetworkProxiesHTTPSPort])).intValue;
            int savedSocksPort = ((NSNumber *)(proxySetting[(__bridge NSString *)kCFNetworkProxiesSOCKSPort])).intValue;
            
            
            BOOL shouldIgnoreAndReset =
            [proxySetting[(__bridge NSString *)kCFNetworkProxiesHTTPProxy] isEqualToString:@"127.0.0.1"] &&
            [proxySetting[(__bridge NSString *)kCFNetworkProxiesSOCKSProxy] isEqualToString:@"127.0.0.1"] &&
            ((NSNumber *)(proxySetting[(__bridge NSString *)kCFNetworkProxiesHTTPEnable])).boolValue &&
            ((NSNumber *)(proxySetting[(__bridge NSString *)kCFNetworkProxiesHTTPSEnable])).boolValue&&
            savedHttpPort == port&&
            savedHttpsPort == port&&
            savedSocksPort== socksPort;
            
            if (savedHttpPort <= 0 || savedHttpsPort <= 0 || savedSocksPort <=0) {
                shouldIgnoreAndReset = YES;
            }
            
            if (shouldIgnoreAndReset) {
                [self disableProxySetting:ref interface:key];
                return;
            }
            
            [self setProxyConfig:ref interface:key proxySetting:proxySetting];
            
        }];
    }];
}

+ (NSMutableDictionary<NSString *,NSDictionary *> *)currentProxySettings {
    __block NSMutableDictionary<NSString *,NSDictionary *> *info = [NSMutableDictionary dictionary];
    SCPreferencesRef ref = SCPreferencesCreate(nil, CFSTR("ClashX"), nil);
    [ProxySettingTool getDiviceListWithPrefRef:ref filterInterface:YES devices:^(NSString *key, NSDictionary *dev) {
        NSDictionary *proxySettings = dev[(__bridge NSString *)kSCEntNetProxies];
        info[key] = [proxySettings copy];
    }];
    CFRelease(ref);
    
    return info;
}

// MARK: - Private

- (void)dealloc {
    [self freeAuth];
}


+ (NSString *)getUserHomePath {
    NSString *userName = [CommonUtils runCommand:@"/usr/bin/stat" args:@[@"-f",@"%Su",@"/dev/console"]];
    userName = [userName stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (!userName) {
        return nil;
    }
    NSString *path = [NSString stringWithFormat:@"/Users/%@", userName];
    if([NSFileManager.defaultManager fileExistsAtPath:path]) {
        return path;
    }
    return nil;
}


- (NSArray<NSString *> *)getIgnoreList {
    NSString *homePath = [ProxySettingTool getUserHomePath];
    if (homePath.length > 0) {
        NSString *configPath = [homePath stringByAppendingString:@"/.config/clash/proxyIgnoreList.plist"];
        if ([NSFileManager.defaultManager fileExistsAtPath:configPath]) {
            NSArray *arr = [[NSArray alloc] initWithContentsOfFile:configPath];
            if (arr != nil && arr.count > 0) {
                return arr;
            }
        }
    }
    NSArray *ignoreList = @[
        @"192.168.0.0/16",
        @"10.0.0.0/8",
        @"172.16.0.0/12",
        @"127.0.0.1",
        @"localhost",
        @"*.local",
        @"timestamp.apple.com"
    ];
    return ignoreList;
}

- (NSDictionary *)getProxySetting:(BOOL)enable port:(int) port
                        socksPort: (int)socksPort pac:(NSString *)pac {
    
    NSMutableDictionary *proxySettings = [NSMutableDictionary dictionary];
    
    NSString *ip = enable ? @"127.0.0.1" : @"";
    NSInteger enableInt = enable ? 1 : 0;
    NSInteger enablePac = [pac length] > 0;
    
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPProxy] = ip;
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPEnable] = @(enableInt);
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSProxy] = ip;
    proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSEnable] = @(enableInt);
    
    proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSProxy] = ip;
    proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSEnable] = @(enableInt);
    
    if (enable) {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPPort] = @(port);
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSPort] = @(port);
        proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSPort] = @(socksPort);
    } else {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPPort] = nil;
        proxySettings[(__bridge NSString *)kCFNetworkProxiesHTTPSPort] = nil;
        proxySettings[(__bridge NSString *)kCFNetworkProxiesSOCKSPort] = nil;
    }
    
    proxySettings[(__bridge NSString *)kCFNetworkProxiesProxyAutoConfigEnable] = @(enablePac);
    if (enablePac) {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesProxyAutoConfigURLString] = pac;
    } else {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesProxyAutoConfigURLString] = nil;
    }
    
    if (enable) {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesExceptionsList] = [self getIgnoreList];
    } else {
        proxySettings[(__bridge NSString *)kCFNetworkProxiesExceptionsList] = @[];
    }
    
    return proxySettings;
}

- (NSString *)proxySettingPathWithInterface:(NSString *)interfaceKey {
    return [NSString stringWithFormat:@"/%@/%@/%@",
            (NSString *)kSCPrefNetworkServices,
            interfaceKey,
            (NSString *)kSCEntNetProxies];
}

- (void)enableProxySettings:(SCPreferencesRef)prefs
                  interface:(NSString *)interfaceKey
                       port:(int) port
                  socksPort:(int) socksPort
                        pac:(NSString *)pac {
    
    NSDictionary *proxySettings = [self getProxySetting:YES port:port socksPort:socksPort pac:pac];
    [self setProxyConfig:prefs interface:interfaceKey proxySetting:proxySettings];
    
}

- (void)disableProxySetting:(SCPreferencesRef)prefs
                  interface:(NSString *)interfaceKey {
    NSDictionary *proxySettings = [self getProxySetting:NO port:0 socksPort:0 pac:nil];
    [self setProxyConfig:prefs interface:interfaceKey proxySetting:proxySettings];
}

- (void)setProxyConfig:(SCPreferencesRef)prefs
             interface:(NSString *)interfaceKey
          proxySetting:(NSDictionary *)proxySettings {
    NSString *path = [self proxySettingPathWithInterface:interfaceKey];
    SCPreferencesPathSetValue(prefs,
                              (__bridge CFStringRef)path,
                              (__bridge CFDictionaryRef)proxySettings);
}

+ (void)getDiviceListWithPrefRef:(SCPreferencesRef)ref
                 filterInterface:(BOOL)filterInterface
                         devices:(void(^)(NSString *, NSDictionary *))callback {
    NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(ref, kSCPrefNetworkServices);
    for (NSString *key in [sets allKeys]) {
        NSMutableDictionary *dict = [sets objectForKey:key];
        NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
        if (!filterInterface || [hardware isEqualToString:@"AirPort"]
            || [hardware isEqualToString:@"Wi-Fi"]
            || [hardware isEqualToString:@"Ethernet"]
            ) {
            callback(key,dict);
        }
    }
}

- (void)applySCNetworkSettingWithRef:(void(^)(SCPreferencesRef))callback {
    SCPreferencesRef ref = SCPreferencesCreateWithAuthorization(nil, CFSTR("com.west2online.ClashX.ProxyConfigHelper.config"), nil, self.authRef);
    if (!ref) {
        return;
    }
    callback(ref);
    
    SCPreferencesCommitChanges(ref);
    SCPreferencesApplyChanges(ref);
    SCPreferencesSynchronize(ref);
    CFRelease(ref);
}

- (AuthorizationFlags)authFlags {
    AuthorizationFlags authFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    return authFlags;
}

- (void)localAuth {
    OSStatus myStatus;
    AuthorizationFlags myFlags = [self authFlags];
    myStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, myFlags, &_authRef);
    
    if (myStatus != errAuthorizationSuccess)
    {
        return;
    }
    
    AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights myRights = {1, &myItems};
    myStatus = AuthorizationCopyRights (self.authRef, &myRights, NULL, myFlags, NULL );
}


- (void)freeAuth {
    if (self.authRef) {
        AuthorizationFree(self.authRef, [self authFlags]);
    }
}


@end
