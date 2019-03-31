import Foundation
import SystemConfiguration

let version = "0.1.3"


func getIgnoreList() -> [String] {
    let configPath = "\(NSHomeDirectory())/.config/clash/proxyIgnoreList.plist"
    if FileManager.default.fileExists(atPath: configPath) {
        if let arr = NSArray(contentsOfFile: configPath) as? [String] {
            return arr
        }
    }
    let ignoreList = [
        "192.168.0.0/16",
        "10.0.0.0/8",
        "172.16.0.0/12",
        "127.0.0.1",
        "localhost",
        "*.local",
        "*.crashlytics.com"
    ]
    return ignoreList
    

}

func getProxySetting(enable:Bool,port:Int,socksPort:Int) -> [String:AnyObject] {
    let ip = enable ? "127.0.0.1" : ""
    let enableInt = enable ? 1 : 0
    
    var proxySettings: [String:AnyObject] = [:]
    proxySettings[kCFNetworkProxiesHTTPProxy as String] = ip as AnyObject
    proxySettings[kCFNetworkProxiesHTTPEnable as String] = enableInt as AnyObject
    proxySettings[kCFNetworkProxiesHTTPSProxy as String] = ip as AnyObject
    proxySettings[kCFNetworkProxiesHTTPSEnable as String] = enableInt as AnyObject
    proxySettings[kCFNetworkProxiesSOCKSProxy as String] = ip as AnyObject
    proxySettings[kCFNetworkProxiesSOCKSEnable as String] = enableInt as AnyObject
    if enable {
        proxySettings[kCFNetworkProxiesHTTPPort as String] = port as AnyObject
        proxySettings[kCFNetworkProxiesHTTPSPort as String] = port as AnyObject
        proxySettings[kCFNetworkProxiesSOCKSPort as String] = socksPort as AnyObject
    } else {
        proxySettings[kCFNetworkProxiesHTTPPort as String] = nil
        proxySettings[kCFNetworkProxiesHTTPSPort as String] = nil
        proxySettings[kCFNetworkProxiesSOCKSPort as String] = nil
    }
    
    let ignoreList = getIgnoreList()
    
    proxySettings[kCFNetworkProxiesExceptionsList as String] = ignoreList as AnyObject
    
    return proxySettings
}


func updateProxySetting(prefs:SCPreferences, interfaceKey:String,enable:Bool,port:Int,socksPort:Int) {
    let proxySettings = getProxySetting(enable: enable, port: port, socksPort: socksPort)
    let path = "/\(kSCPrefNetworkServices)/\(interfaceKey)/\(kSCEntNetProxies)"
    SCPreferencesPathSetValue(prefs, path as CFString, proxySettings as CFDictionary)
}

func main(_ args: [String]) {
    var port: Int = 0
    var socksPort = 0
    var flag: Bool = false
    
    if args.count > 3 {
        guard let _port = Int(args[1]),
            let _socksPort = Int(args[2]) else {
                print("ERROR: port is invalid.")
                exit(EXIT_FAILURE)
        }
        guard args[3] == "enable" || args[3] == "disable" else {
            print("ERROR: flag is invalid.")
            exit(EXIT_FAILURE)
        }
        port = _port
        socksPort = _socksPort
        flag = args[3] == "enable"
    } else if args.count == 2 && args[1] == "version"{
        print(version)
        exit(EXIT_SUCCESS)
    } else {
        print("Usage: ProxyConfig <port> <socksPort> <enable/disable>")
        exit(EXIT_FAILURE)
    }
    
    var authRef: AuthorizationRef? = nil
    let authFlags: AuthorizationFlags = [.extendRights, .interactionAllowed, .preAuthorize]
    
    let authErr = AuthorizationCreate(nil, nil, authFlags, &authRef)
    
    defer {
        AuthorizationFree(authRef!, AuthorizationFlags())
    }
    
    guard authErr == noErr else {
        print("Error: Failed to create administration authorization due to error \(authErr).")
        exit(EXIT_FAILURE)
    }
    
    guard authRef != nil else {
        print("Error: No authorization has been granted to modify network configuration.")
        exit(EXIT_FAILURE)
    }
    
    guard let prefRef = SCPreferencesCreateWithAuthorization(nil, "ClashX" as CFString, nil, authRef),
        let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices)
        else {
            print("Error: SCPreferencesGetValue fail")
            exit(EXIT_FAILURE)
    }
    
    for key in sets.allKeys {
        // 遍历所有接口进行设置
        let dict = sets.object(forKey: key) as? NSDictionary
        let hardware = ((dict?["Interface"]) as? NSDictionary)?["Hardware"] as? String
        if hardware == "AirPort" || hardware == "Ethernet" {
            updateProxySetting(prefs: prefRef,
                               interfaceKey: key as! String,
                               enable: flag,
                               port: port,
                               socksPort: socksPort)
        }
    }
    
    SCPreferencesCommitChanges(prefRef)
    SCPreferencesApplyChanges(prefRef)
    
}

main(CommandLine.arguments)
