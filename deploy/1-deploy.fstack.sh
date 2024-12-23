apt update
apt-get install git gcc openssl libssl-dev linux-headers-$(uname -r) bc libnuma1 libnuma-dev libpcre3 libpcre3-dev zlib1g-dev meson python3-pip gawk -y
pip3 install pyelftools

mkdir -p /data/
wget https://wiki.hoanghd.com/wp-content/uploads/codes/f-stack.tar -O /data/f-stack.tar
cd /data/
tar -xvf f-stack.tar
# git clone https://github.com/F-Stack/f-stack.git /data/f-stack

cd /data/f-stack/dpdk
sed -i 's/if (pci_intx_mask_supported(udev->pdev)) {/if (true || pci_intx_mask_supported(udev->pdev)) {/' /data/f-stack/dpdk/kernel/linux/igb_uio/igb_uio.c

meson -Denable_kmods=true -Ddisable_libs=flow_classify build
ninja -C build
ninja -C build install

echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

mkdir /mnt/huge
mount -t hugetlbfs nodev /mnt/huge
cat >> /etc/fstab << 'OEF'
nodev /mnt/huge hugetlbfs defaults 0 0
OEF
mount -a

modprobe uio
insmod /data/f-stack/dpdk/build/kernel/linux/igb_uio/igb_uio.ko
insmod /data/f-stack/dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on

cd /data/f-stack/dpdk/usertools

ifconfig ens192 down
python3 dpdk-devbind.py --bind=igb_uio ens192
python3 dpdk-devbind.py --status

apt install pkg-config -y

# find /usr/local -type f -name '*.pc'

export FF_PATH=/data/f-stack
export PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig

cd /data/f-stack/lib
make
make install

# build f-stack
apt update
apt install curl gnupg2 ca-certificates lsb-release debian-archive-keyring -y
apt install build-essential libpcre3-dev libssl-dev zlib1g-dev libgd-dev -y

# download nginx custom modules
mkdir /opt/modules
cd /opt/modules/
git clone https://github.com/yaoweibin/nginx_upstream_check_module
git clone https://github.com/vozlt/nginx-module-vts
git clone https://github.com/openresty/headers-more-nginx-module

cd /opt/modules/
wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v0.3.3.tar.gz
tar -xzvf v0.3.3.tar.gz

export LUAJIT_LIB=/usr/local/lib 
export LUAJIT_INC=/usr/local/include/luajit-2.1

cd /data/f-stack/app/nginx-1.25.2

# # # ###
# nginx_version=1.25.2
# cd /opt/
# wget http://nginx.org/download/nginx-${nginx_version}.tar.gz
# tar -xzvf nginx-${nginx_version}.tar.gz
# cd /opt/nginx-${nginx_version}

patch -p1 --verbose < /opt/modules/nginx_upstream_check_module/check_1.20.1+.patch

./configure \
    --prefix=/etc/nginx --with-ff_module \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/run/nginx.pid \
    --lock-path=/var/lock/nginx.lock \
    --http-client-body-temp-path=/var/lib/nginx/body \
    --http-proxy-temp-path=/var/lib/nginx/proxy \
    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
    --user=www-data \
    --group=www-data \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_gzip_static_module \
    --with-http_v2_module \
    --with-http_ssl_module \
    --with-pcre-jit \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-debug \
    --with-ld-opt="-Wl,-rpath,/usr/local/lib" \
    --add-module=/opt/modules/nginx_upstream_check_module \
    --add-module=/opt/modules/headers-more-nginx-module \
    --add-module=/opt/modules/nginx-module-vts \
    --add-module=/opt/modules/ngx_devel_kit-0.3.3
    # --add-module=/opt/modules/lua-nginx-module-0.10.2

sed -i 's/ngx_http_upstream_check_peer_down(peer->check_index)/ngx_http_upstream_check_peer_down(i)/' /opt/modules/nginx-module-vts/src/ngx_http_vhost_traffic_status_display_json.c
sed -i 's/if (ngx_notify == NULL) {/if (0) {/' /data/f-stack/app/nginx-1.25.2/src/core/ngx_thread_pool.c
# sed -i 's/if (ngx_add_event) {/if (0) {/' /opt/modules/lua-nginx-module-0.10.26/src/ngx_http_lua_socket_udp.c

make -j$(nproc)
make install

mkdir -p /var/lib/nginx/body
chmod 700 /var/lib/nginx/body

nginx -V

cat > /etc/nginx/f-stack.conf << 'OEF'
[dpdk]
lcore_mask=4
channel=4
promiscuous=1
numa_on=1
tx_csum_offoad_skip=0
tso=0
vlan_strip=1
idle_sleep=0
pkt_tx_delay=100
symmetric_rss=0
port_list=0
nb_vdev=0
nb_bond=0

[pcap]
enable = 0
snaplen= 96
savelen= 16777216

[port0]
addr=10.237.7.79
netmask=255.255.255.0
broadcast=10.237.7.255
gateway=10.237.7.1

[freebsd.boot]
hz=100
fd_reserve=1024
kern.ipc.maxsockets=262144
net.inet.tcp.syncache.hashsize=4096
net.inet.tcp.syncache.bucketlimit=100
net.inet.tcp.tcbhashsize=65536
kern.ncallout=262144
kern.features.inet6=1
net.inet6.ip6.auto_linklocal=1
net.inet6.ip6.accept_rtadv=2
net.inet6.icmp6.rediraccept=1
net.inet6.ip6.forwarding=0

[freebsd.sysctl]
kern.ipc.somaxconn=32768
kern.ipc.maxsockbuf=16777216
net.link.ether.inet.maxhold=5
net.inet.tcp.fast_finwait2_recycle=1
net.inet.tcp.sendspace=16384
net.inet.tcp.recvspace=8192
net.inet.tcp.cc.algorithm=cubic
net.inet.tcp.sendbuf_max=16777216
net.inet.tcp.recvbuf_max=16777216
net.inet.tcp.sendbuf_auto=1
net.inet.tcp.recvbuf_auto=1
net.inet.tcp.sendbuf_inc=16384
net.inet.tcp.recvbuf_inc=524288
net.inet.tcp.sack.enable=1
net.inet.tcp.blackhole=1
net.inet.tcp.msl=2000
net.inet.tcp.delayed_ack=0
net.inet.udp.blackhole=1
net.inet.ip.redirect=0
net.inet.ip.forwarding=0
OEF

cat > /etc/nginx/nginx.conf << EOF
user  root;
worker_processes auto;
fstack_conf f-stack.conf;
events {
    worker_connections  102400;
    use kqueue;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        off;
    keepalive_timeout  65;
    server {
        listen       80;
        server_name  localhost;
        access_log /dev/null;
        location / {
            return 200 "<h1>Hello, World! F-Stack ($(hostname))</h1>";
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF

nginx -t