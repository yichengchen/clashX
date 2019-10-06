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
- Support for Netfilter TCP redirect

## Install

You can download from [release](https://github.com/yichengchen/clashX/releases) page

## Build
- Download deps
  ```
  bash install_dependency.sh
  ```
- Build clash core. 
  ```
  cd ClashX
  python3 build_clash.py
  ```
- Build and run.

## Config


The default configuration directory is `$HOME/.config/clash`

The default name of the configuration file is `config.ymal`. You can use your custom config name and switch config in menu `Config` section.

To Change the ports of ClashX, you need to modify the `config.ymal` file. The `General` section settings in your custom config file would be ignored.

Checkout [Clash](https://github.com/Dreamacro/clash) or [SS-Rule-Snippet for Clash](https://github.com/Hackl0us/SS-Rule-Snippet/blob/master/LAZY_RULES/clash.yml) for more detail.

## Advance Config
### Change your status menu icon

  Place your icon file in the `~/.config/clash/menuImage.png`  then restart ClashX

### Disable auto restore proxy setting.

  ```
  defaults write com.west2online.ClashX kDisableRestoreProxy -bool true
  ```

### Change default system ignore list.

- Download sample plist in the [Here](proxyIgnoreList.plist) and place in the

  ```
  ~/.config/clash/proxyIgnoreList.plist
  ```

- Edit the `proxyIgnoreList.plist` to set up your own proxy ignore list

### Use url scheme to import remote config.

- Using url scheme describe below

  ```
  clash://install-config?url=http%3A%2F%2Fexample.com&name=example
  ```

### Follow system hosts.

- Enable system hosts override using follow command in terimal. The hosts setting would be ignored.

  ```
  defaults write com.west2online.ClashX kEnableSystemHostsOverride -bool true
  ```


### Use own clash core.

- Enable develop mode by command line
  ```
  defaults write com.west2online.ClashX kDeveloperMode -bool true
  ```

- Launch your own clash core before clashX started.



