<h1 align="center">
  <img src="https://github.com/Dreamacro/clash/raw/master/docs/logo.png" alt="Clash" width="200">
  <br>
  ClashX
  <br>
</h1>


A rule based proxy For Mac base on [Clash](https://github.com/Dreamacro/clash).



## Features

- HTTP/HTTPS and SOCKS protocol
- Surge like configuration
- GeoIP rule support
- Support Vmess/Shadowsocks/Socks5
- Support for Netfilter TCP redire

## Install

You can download from [release](https://github.com/yichengchen/clashX/releases) page

## Build
- Download mmdb from http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz unzip and put it in the "ClashX/Support Files/Country.mmdb".

- Open the "ClashX/Resources" folder and clone the dashboard project.
  ```
  git clone -b gh-pages git@github.com:Dreamacro/clash-dashboard.git dashboard
  ```
- Build clash core. 
  ```
  go build -buildmode=c-archive
  ```
- Build and run.

## Config


The default configuration directory is `$HOME/.config/clash`

The default name of the configuration file is `config.yml`. You can use your custom config name and switch config in menu "Config" section.

Checkout [Clash](https://github.com/Dreamacro/clash) or [SS-Rule-Snippet for Clash](https://github.com/Hackl0us/SS-Rule-Snippet/blob/master/LAZY_RULES/clash.yml) for more detail.

## Advance Config
### Change your status menu icon

    Place your icon file in the ~/.config/clash/menuImage.png then restart ClashX

### Change default system ignore list.

    - Download sample plist in the [Here](https://baidu.com) and place in the ~/.config/clash/proxyIgnoreList.plist

    - edit the proxyIgnoreList.plist to set up your own proxy ignore list



