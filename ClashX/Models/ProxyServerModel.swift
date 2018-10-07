//
//  ProxyServerModel.swift
//  ClashX
//
//  Created by CYC on 2018/8/5.
//  Copyright © 2018年 yichengchen. All rights reserved.
//

import Cocoa

enum ProxyType:Int, Codable {
    case shadowsocks = 0
    case socks5
}

enum SimpleObfsType:String, Codable {
    case none = "none"
    case http = "http"
    case tls = "tls"
}

class ProxyServerModel: NSObject, Codable {
    @objc dynamic var serverHost:String = ""
    @objc dynamic var serverPort:String = ""
    @objc dynamic var password:String = ""
    @objc dynamic var method:String = "RC4-MD5"
    @objc dynamic var remark:String = "NewProxy"
    var simpleObfs:SimpleObfsType = .none {
        didSet {
            switch simpleObfs {
            case .none:pluginStr = ""
            case .http:pluginStr = ",obfs=http,obfs-host=bing.com"
            case .tls:pluginStr =  ",obfs=tls,obfs-host=bing.com"
            }
        }
    }
    
    var pluginStr = ""
    var proxyType:ProxyType = .shadowsocks

    
    static let supportMethod = [
        "RC4-MD5",
        "AES-128-CTR",
        "AES-192-CTR",
        "AES-256-CTR",
        "AES-128-CFB",
        "AES-192-CFB",
        "AES-256-CFB",
        "CHACHA20",
        "CHACHA20-IETF",
        "XCHACHA20",
        "AEAD_AES_128_GCM",
        "AEAD_AES_192_GCM",
        "AEAD_AES_256_GCM",
        "AEAD_CHACHA20_POLY1305"
    ]
    
    
    convenience init?(urlStr: String) {
        self.init()
        if !urlStr.hasPrefix("ss://") {return nil}
        
        var allowSet = CharacterSet.urlFragmentAllowed
        allowSet.insert("#")
        let fixUrlStr = urlStr.addingPercentEncoding(withAllowedCharacters: allowSet)
        guard let url = URL(string: fixUrlStr ?? "") else {return nil}
        func padBase64(string: String) -> String {
            var length = string.count
            if length % 4 == 0 {
                return string
            } else {
                length = 4 - length % 4 + length
                return string.padding(toLength: length, withPad: "=", startingAt: 0)
            }
        }
        
        func decodeUrl(url: URL) -> String? {
            let urlStr = url.absoluteString
            let index = urlStr.index(urlStr.startIndex, offsetBy: 5)
            let encodedStr = urlStr[index...]
            guard let data = Data(base64Encoded: padBase64(string: String(encodedStr))) else {
                return url.absoluteString
            }
            guard let decoded = String(data: data, encoding: String.Encoding.utf8) else {
                return nil
            }
            let s = decoded.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            return "ss://\(s)"
        }
        
        guard let decodedUrl = decodeUrl(url: url) else {
            return nil
        }
        guard var parsedUrl = URLComponents(string: decodedUrl) else {
            return nil
        }
        guard let host = parsedUrl.host, let port = parsedUrl.port,
            let user = parsedUrl.user else {
                return nil
        }
        
        self.serverHost = host
        self.serverPort = "\(port)"
        
        // This can be overriden by the fragment part of SIP002 URL
        remark = parsedUrl.queryItems?
            .filter({ $0.name == "Remark" }).first?.value ?? "\(parsedUrl.host?.split(separator: ".").first ?? "Proxy")\(arc4random()%10)"
        
        if let password = parsedUrl.password {
            self.method = user.uppercased()
            self.password = password
        } else {
            // SIP002 URL have no password section
            guard let data = Data(base64Encoded: padBase64(string: user)),
                let userInfo = String(data: data, encoding: .utf8) else {
                    return nil
            }
            
            let parts = userInfo.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count != 2 {
                return nil
            }
            self.method = String(parts[0]).uppercased()
            self.password = String(parts[1])
            
            // SIP002 defines where to put the profile name
            if let profileName = parsedUrl.fragment?.removingPercentEncoding {
                self.remark = profileName
            }
        }
        
        if let pluginStr = parsedUrl.queryItems?
            .filter({ $0.name == "plugin" }).first?.value {
            let parts = pluginStr.split(separator: ";", maxSplits: 1)
            if parts.count == 2 {
                self.pluginStr = String(parts[1])
            }
        }
        
        if (!self.isValid()) {
            return nil
        }
    }
    
    func isValid() -> Bool {
        var whitespace = NSCharacterSet.whitespacesAndNewlines
        whitespace.insert(":")
        remark = remark.components(separatedBy: whitespace).joined()
        if remark == "" {remark = "NewProxy"}
        
        func validateIpAddress(_ ipToValidate: String) -> Bool {
            
            var sin = sockaddr_in()
            var sin6 = sockaddr_in6()
            
            if ipToValidate.withCString({ cstring in inet_pton(AF_INET6, cstring, &sin6.sin6_addr) }) == 1 {
                // IPv6 peer.
                return true
            }
            else if ipToValidate.withCString({ cstring in inet_pton(AF_INET, cstring, &sin.sin_addr) }) == 1 {
                // IPv4 peer.
                return true
            }
            
            return false;
        }
        
        func validateDomainName(_ value: String) -> Bool {
            // this regex from ss-ng seems useless
            let validHostnameRegex = "^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$"
            
            if (value.range(of: validHostnameRegex, options: .regularExpression) != nil) {
                return true
            } else {
                return false
            }
        }
        
        func vaildatePort(_ value: String) -> Bool {
            if let port = Int(value) {
                return port > 0 && port <= 65535
            }
            return false
        }
        
        func vaildateMethod() -> Bool {
            self.method = self.method.uppercased()
            return type(of: self).supportMethod.contains(self.method)
        }
        
        if !(validateIpAddress(serverHost) || validateDomainName(serverHost)) {
            return false
        }
        
        if !(vaildatePort(serverPort)) {
            return false
        }
        
        if self.proxyType == .shadowsocks {
            if !vaildateMethod() || password.isEmpty {
                return false
            }
        }

        
        return true
    }
    
    override func copy() -> Any {
        guard let data = try? JSONEncoder().encode(self) else {return ProxyServerModel()}
        let copy = try? JSONDecoder().decode(ProxyServerModel.self, from: data)
        return copy ?? ProxyServerModel()
    }
    

}
