wget http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz
tar -zxvf GeoLite2-Country.tar.gz
mv GeoLite2-Country_*/GeoLite2-Country.mmdb ./ClashX/Support\ Files/Country.mmdb
cd ClashX/Resources
git clone -b gh-pages git@github.com:Dreamacro/clash-dashboard.git dashboard
cd ..
brew upgrade go
go build -buildmode=c-archive

xcodebuild -workspace ClashX.xcworkspace -scheme "ClashX" build CODE_SIGN_IDENTITY="Developer ID Application: Fuzhou West2Online Internet Inc. (MEWHFZ92DY)" | xcpretty
gem install gym
fastlane gym -s SpechtLite --disable_xcpretty
