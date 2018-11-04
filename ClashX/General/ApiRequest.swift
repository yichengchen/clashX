//
//  ApiRequest.swift
//  ClashX
//
//  Created by CYC on 2018/7/30.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa
import Alamofire
import SwiftyJSON


class ApiRequest{
    static let shared = ApiRequest()
    private init(){
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 604800
        configuration.timeoutIntervalForResource = 604800
        alamoFireManager = Alamofire.SessionManager(configuration: configuration)
    }
    
    private static func authHeader() -> HTTPHeaders? {
        let secret = ConfigManager.shared.apiSecret
        return (secret != nil) ? ["Authorization":"Bearer \(secret ?? "")"] : nil;
        
    }
    
    private static func req(
        _ url: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default)
        -> DataRequest {
            guard ConfigManager.shared.isRunning else {
                return request("")
            }

            return request(ConfigManager.apiUrl + url,
                method: method,
                parameters: parameters,
                encoding:encoding,
                headers: authHeader())
    }
    
    var trafficReq:DataRequest? = nil
    var logReq:DataRequest? = nil
    var alamoFireManager:SessionManager!
    

    static func requestConfig(completeHandler:@escaping ((ClashConfig)->())){
        req("/configs").responseData{
            res in
            guard let data = res.result.value else {return}
            let config = ClashConfig.fromData(data)
            completeHandler(config)
        }
    }
    
    
    static func requestConfigUpdate(callback:@escaping ((String?)->())){
        if let errMSg = updateAllConfig() {
            let err = String(cString: errMSg)
            let success = (err == "")
            ConfigManager.shared.isRunning = success
            callback(success ? nil : err)
        } else {
            callback("unknown error")
        }
        req("/configs", method: .put).responseJSON {_ in}
    }
    
    static func updateOutBoundMode(mode:ClashProxyMode, callback:@escaping ((Bool)->())) {
        req("/configs", method: .put, parameters: ["mode":mode.rawValue], encoding: JSONEncoding.default)
            .responseJSON{ response in
            switch response.result {
            case .success(_):
                callback(true)
            case .failure(_):
                callback(false)
            }
        }
    }
    
    static func requestProxyGroupList(completeHandler:@escaping (([String:[String:Any]])->())){
        req("/proxies").responseJSON{
            res in
            guard let data = res.result.value as? [String:[String:[String:Any]]] else {return}
            completeHandler(data["proxies"]!)
        }
    }
    
    static func updateAllowLan(allow:Bool,completeHandler:@escaping (()->())) {
        req("/configs",
            method: .put,
            parameters: ["allow-lan":allow],
            encoding: JSONEncoding.default).response{
            _ in
            completeHandler()
        }
    }
    
    static func updateProxyGroup(group:String,selectProxy:String,callback:@escaping ((Bool)->())) {
        let groupEncoded = group.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        req("/proxies/\(groupEncoded)",
            method: .put,
            parameters: ["name":selectProxy],
            encoding: JSONEncoding.default)
            .responseJSON { (response) in
            callback(response.response?.statusCode == 204)
        }
    }
    
    static func getAllProxyList(callback:@escaping (([String])->())) {
        requestProxyGroupList { (groups) in
            let lists:[String] = groups["GLOBAL"]?["all"] as? [String] ?? []
            var proxyList = [String]()
            for proxy in lists {
                if ["Shadowsocks","Vmess"] .contains(groups[proxy]?["type"] as? String ?? ""){
                    proxyList.append(proxy)
                }
            }
            callback(proxyList)
        }
    }
    
    static func getProxyDelay(proxyName:String,callback:@escaping ((Int)->())) {
        let proxyNameEncoded = proxyName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""

        req("/proxies/\(proxyNameEncoded)/delay"
            , method: .get
            , parameters: ["timeout":5000,"url":"http://www.gstatic.com/generate_204"])
            .responseJSON { (res) in let json = JSON(res.result.value ?? [])
                callback(json["delay"].int ?? Int.max)
        }
    }
    
    static func getRules(completeHandler:@escaping ([ClashRule])->()) {
        req("/rules").responseData { res in
            guard let data = res.result.value else {return}
            let rule = ClashRuleResponse.fromData(data)
            completeHandler(rule.rules)
        }
    }
}

// Stream Apis
extension ApiRequest {
    func requestTrafficInfo(retryTimes:Int = 0, callback:@escaping ((Int,Int)->()) ){
        trafficReq?.cancel()
        var retry = retryTimes
        if (retry > 5) {
            NSUserNotificationCenter.default.postStreamApiConnectFail(api:"Traffic")
            return
        }
        
        trafficReq =
            alamoFireManager
                .request(ConfigManager.apiUrl + "/traffic",
                         headers:ApiRequest.authHeader())
                .stream {(data) in
                    retry = 0
                    if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String:Int] {
                        callback(jsonData?["up"] ?? 0, jsonData?["down"] ?? 0)
                    }
                }.response { res in
                    guard let err = res.error else {return}
                    if (err as NSError).code != -999 {
                        Logger.log(msg: "Traffic Api.\(err.localizedDescription)")
                        // delay 1s,prevent recursive
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                            self.requestTrafficInfo(retryTimes: retry + 1, callback: callback)
                        })
                    }
        }
    }
    
    func requestLog(retryTimes:Int = 0,callback:@escaping ((String,String)->())){
        logReq?.cancel()
        var retry = retryTimes
        if (retry > 5) {
            NSUserNotificationCenter.default.postStreamApiConnectFail(api:"Log")
            return
        }
        
        logReq =
            alamoFireManager
                .request(ConfigManager.apiUrl + "/logs?level=\(ConfigManager.selectLoggingApiLevel.rawValue)",
                    headers:ApiRequest.authHeader())
                .stream {(data) in
                    retry = 0
                    if let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String:String] {
                        let type = jsonData!["type"] ?? "info"
                        let payload = jsonData!["payload"] ?? ""
                        callback(type,payload)
                    }
                }
                .response { res in
                    guard let err = res.error else {return}
                    if (err as NSError).code != -999 {
                        Logger.log(msg: "Loging api disconnected.\(err.localizedDescription)")
                        // delay 1s,prevent recursive
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1, execute: {
                            self.requestLog(retryTimes: retry + 1, callback: callback)
                        })
                    }
        }
    }
    
}
