#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>


NSString const* version = @"0.1.3";


NSArray<NSString *>* getIgnoreList() {
    NSString *configPath = [NSHomeDirectory() stringByAppendingString:@"/.config/clash/proxyIgnoreList.plist"];
    if ([NSFileManager.defaultManager fileExistsAtPath:configPath]) {
        NSArray *arr = [[NSArray alloc] initWithContentsOfFile:configPath];
        if (arr != nil && arr.count > 0 && [arr containsObject:@"127.0.0.1"]) {
            return arr;
        }
    }
    NSArray *ignoreList = @[
                            @"192.168.0.0/16",
                            @"10.0.0.0/8",
                            @"172.16.0.0/12",
                            @"127.0.0.1",
                            @"localhost",
                            @"*.local",
                            @"*.crashlytics.com"
                            ];
    return ignoreList;
    
}

NSDictionary* getProxySetting(BOOL enable,
                        int port,
                        int socksPort){
    NSMutableDictionary *proxySettings = [NSMutableDictionary dictionary];
    
    NSString *ip = enable ? @"127.0.0.1" : @"";
    NSInteger enableInt = enable ? 1 : 0;
    
    proxySettings[(NSString *)kCFNetworkProxiesHTTPProxy] = ip;
    proxySettings[(NSString *)kCFNetworkProxiesHTTPEnable] = @(enableInt);
    proxySettings[(NSString *)kCFNetworkProxiesHTTPSProxy] = ip;
    proxySettings[(NSString *)kCFNetworkProxiesHTTPSEnable] = @(enableInt);

    proxySettings[(NSString *)kCFNetworkProxiesSOCKSProxy] = ip;
    proxySettings[(NSString *)kCFNetworkProxiesSOCKSEnable] = @(enableInt);
    
    if (enable) {
        proxySettings[(NSString *)kCFNetworkProxiesHTTPPort] = @(port);
        proxySettings[(NSString *)kCFNetworkProxiesHTTPSPort] = @(port);
        proxySettings[(NSString *)kCFNetworkProxiesSOCKSPort] = @(socksPort);
    } else {
        proxySettings[(NSString *)kCFNetworkProxiesHTTPPort] = nil;
        proxySettings[(NSString *)kCFNetworkProxiesHTTPSPort] = nil;
        proxySettings[(NSString *)kCFNetworkProxiesSOCKSPort] = nil;
    }

    
    proxySettings[(NSString *)kCFNetworkProxiesExceptionsList] = getIgnoreList();
    
    return proxySettings;
}

void updateProxySettings(SCPreferencesRef prefs,
                         NSString *interfaceKey,
                         BOOL enable,
                         int port,
                         int socksPort) {
    NSDictionary *proxySettings = getProxySetting(enable, port, socksPort);
    NSString *path = [NSString stringWithFormat:@"/%@/%@/%@",
                      (NSString *)kSCPrefNetworkServices,
                      interfaceKey,
                      (NSString *)kSCEntNetProxies];
    SCPreferencesPathSetValue(prefs,
                              (__bridge CFStringRef)path,
                              (__bridge CFDictionaryRef)proxySettings);
}

NSArray<NSString *> *parseArgs(int argc, const char * argv[]) {
    NSMutableArray *results = [NSMutableArray array];
    for (int i = 0; i < argc; i++) {
        NSString *str = [[NSString alloc] initWithCString:argv[i] encoding:NSUTF8StringEncoding];
        [results addObject:str];
    }
    return results;
}

int main(int argc, const char * argv[]) {
    int port = 0;
    int socksPort = 0;
    BOOL flag = NO;
    
    NSArray *args = parseArgs(argc,argv);
    if (args.count > 3) {
        port = [args[1] intValue];
        socksPort = [args[2] intValue];
        if ([args[3] isEqualToString:@"enable"]) {
            flag = YES;
        } else if ([args[3] isEqualToString:@"disable"]) {
            flag = NO;
        } else {
            printf("ERROR: flag is invalid.");
            exit(EXIT_FAILURE);
        }
    } else if (args.count == 2 && [args[1] isEqualToString:@"version"]) {
        printf("%s",[version UTF8String]);
        exit(EXIT_SUCCESS);
    } else {
        printf("Usage: ProxyConfig <port> <socksPort> <enable/disable>");
        exit(EXIT_FAILURE);
    }
    
    static AuthorizationRef authRef;
    static AuthorizationFlags authFlags;
    authFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    OSStatus authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, &authRef);
    
    if (authErr != noErr || authRef == NULL) {
        authRef = nil;
        printf("Error when create authorization");
        exit(EXIT_FAILURE);
    }
    
    SCPreferencesRef prefRef = SCPreferencesCreateWithAuthorization(nil, CFSTR("ClashX"), nil, authRef);
    
    NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(prefRef, kSCPrefNetworkServices);
    
    if (!prefRef || ! sets) {
        printf("Error: SCPreferencesGetValue fail");
        AuthorizationFree(authRef, authFlags);
        exit(EXIT_FAILURE);
    }

    for (NSString *key in [sets allKeys]) {
        NSMutableDictionary *dict = [sets objectForKey:key];
        NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
        if ([hardware isEqualToString:@"AirPort"]
            || [hardware isEqualToString:@"Wi-Fi"]
            || [hardware isEqualToString:@"Ethernet"]) {
            updateProxySettings(prefRef, key, flag, port, socksPort);
        }
    }
    
    SCPreferencesCommitChanges(prefRef);
    SCPreferencesApplyChanges(prefRef);
    SCPreferencesSynchronize(prefRef);

    AuthorizationFree(authRef, authFlags);
    
    return 0;
}
