#!/bin/bash
set -e
echo "Build Clash core"

if [ "$1" = "skip-build-go" ]; then
    echo "skip build go"
else
    cd ClashX/goClash
    python3 build_clash.py
    cd ../..
fi
echo "Pod install"
pod install
echo "delete old files"
rm -f ./ClashX/Resources/Country.mmdb
rm -rf ./ClashX/Resources/dashboard
rm -f GeoLite2-Country.*
echo "install mmdb"
curl -LO https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb
gzip Country.mmdb
mv Country.mmdb.gz ./ClashX/Resources/Country.mmdb.gz
echo "install dashboard"
cd ClashX/Resources
git clone -b gh-pages https://github.com/Dreamacro/clash-dashboard.git dashboard
