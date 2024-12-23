export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig
ls -l /data/f-stack/tools
ls -l /data/f-stack/tools/ifconfig/
cd /data/f-stack/tools
make
make install
ls -l /usr/local/bin/f-stack/
cd /usr/local/bin/f-stack/
./ifconfig