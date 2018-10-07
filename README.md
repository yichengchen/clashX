<h1 align="center">
  <img src="https://github.com/Dreamacro/clash/raw/master/docs/logo.png" alt="Clash" width="200">
  <br>
  ClashX
  <br>
</h1>


A rule based proxy For Mac base on [Clash](https://github.com/Dreamacro/clash).

### <b>Star and Support the upstream [Clash](https://github.com/Dreamacro/clash) , Thank You!</b>

Telegram Group: [Join](https://t.me/clash_discuss)

# Features

HTTP/HTTPS and SOCKS proxy
Surge like configuration
GeoIP rule support



# Install

You can download from [release](https://github.com/yichengchen/clashX/releases) page


# Config
You can use config generator in Status Bar Menu "Config" section.
Config support most of surge rules.

Configuration file at $HOME/.config/clash/config.ini

Below is a simple demo configuration file:
```
[General]
port = 7890
socks-port = 7891

# A RESTful API for clash
external-controller = 127.0.0.1:8080 // do not change this line when you are using clashX

[Proxy]
# name = ss, server, port, cipher, password
# The types of cipher are consistent with go-shadowsocks2
# support AEAD_AES_128_GCM AEAD_AES_192_GCM AEAD_AES_256_GCM AEAD_CHACHA20_POLY1305 AES-128-CTR AES-192-CTR AES-256-CTR AES-128-CFB AES-192-CFB AES-256-CFB CHACHA20-IETF XCHACHA20 RC4-MD5
Proxy1 = ss, server1, port, AEAD_CHACHA20_POLY1305, password
Proxy2 = ss, server2, port, AEAD_CHACHA20_POLY1305, password

[Proxy Group]
# url-test select which proxy will be used by benchmarking speed to a URL.
# name = url-test, [proxys], url, interval(second)
ProxyAuto = url-test, Proxy1, Proxy2, http://www.google.com/generate_204, 300

Proxy = select, Proxy1, Proxy2 ,ProxyAuto // ProxyAuto should be placed before this line 


[Rule]
DOMAIN-SUFFIX,google.com,Proxy
DOMAIN-KEYWORD,google,Proxy
DOMAIN-SUFFIX,ad.com,REJECT
GEOIP,CN,DIRECT
FINAL,,Proxy // notice there are two ","

```
