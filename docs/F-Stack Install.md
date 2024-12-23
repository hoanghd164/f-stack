## F-Stack install
This script installs and configures F-Stack and Nginx with custom modules on a Linux system. It includes steps to install dependencies, build DPDK and F-Stack, configure hugepages, load kernel modules, bind network interfaces, and configure Nginx with custom modules. Finally, it sets up the necessary configuration files for F-Stack and Nginx.

### Step 1: Update and Install Dependencies *
```
apt update
apt-get install git gcc openssl libssl-dev linux-headers-$(uname -r) bc libnuma1 libnuma-dev libpcre3 libpcre3-dev zlib1g-dev meson python3-pip gawk -y

```
* Update package lists: apt update
* Install necessary packages: git, gcc, openssl, libssl-dev, linux-headers, bc, libnuma1, libnuma-dev, libpcre3, libpcre3-dev, zlib1g-dev, meson, python3-pip, gawk

#### Install Python package: pyelftools
```
pip3 install pyelftools
```

### Step 2: Clone F-Stack Repository
```
mkdir -p /data/
git clone https://github.com/F-Stack/f-stack.git /data/f-stack
```
* Create directory: /data/
* Clone F-Stack repository: into /data/f-stack

### Step 3: Build DPDK
```
cd /data/f-stack/dpdk
sed -i 's/if (pci_intx_mask_supported(udev->pdev)) {/if (true || pci_intx_mask_supported(udev->pdev)) {/' /data/f-stack/dpdk/kernel/linux/igb_uio/igb_uio.c

meson -Denable_kmods=true -Ddisable_libs=flow_classify build
ninja -C build
ninja -C build install
```
* Navigate to DPDK directory: cd /data/f-stack/dpdk
* Modify source code: sed -i 's/if (pci_intx_mask_supported(udev->pdev)) {/if (true || pci_intx_mask_supported(udev->pdev)) {/' /data/f-* stack/dpdk/kernel/linux/igb_uio/igb_uio.c
* Build DPDK: using meson and ninja

### Step 4: Configure Hugepages
```
echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages

mkdir /mnt/huge
mount -t hugetlbfs nodev /mnt/huge
cat >> /etc/fstab << 'OEF'
nodev /mnt/huge hugetlbfs defaults 0 0
OEF
mount -a
```
* Set hugepages: echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
* Create mount point: mkdir /mnt/huge
* Mount hugepages: mount -t hugetlbfs nodev /mnt/huge
* Add to fstab: to ensure hugepages are mounted on boot

### Step 5: Load Kernel Modules
```
modprobe uio
insmod /data/f-stack/dpdk/build/kernel/linux/igb_uio/igb_uio.ko
insmod /data/f-stack/dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on
```
* Load UIO module: modprobe uio
* Insert DPDK kernel modules: igb_uio and rte_kni

### Step 6: Bind Network Interface to DPDK
```
cd /data/f-stack/dpdk/usertools

ifconfig ens192 down
python3 dpdk-devbind.py --bind=igb_uio ens192
python3 dpdk-devbind.py --status
```
* Navigate to usertools directory: cd /data/f-stack/dpdk/usertools
* Bring down network interface: ifconfig ens192 down
* Bind interface to DPDK driver: python3 dpdk-devbind.py --bind=igb_uio ens192
* Check status: python3 dpdk-devbind.py --status

### Step 7: Install pkg-config
```
apt install pkg-config -y
```

### Step 8: Set Environment Variables
```
export FF_PATH=/data/f-stack
export PKG_CONFIG_PATH=/usr/local/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig
```
* Set environment variables: FF_PATH and PKG_CONFIG_PATH

### Step 9: Build F-Stack Libraries
```
cd /data/f-stack/lib
make
make install
```
* Navigate to F-Stack library directory: cd /data/f-stack/lib
* Build and install libraries: make and make install

### Step 10: Install Additional Dependencies
```
apt update
apt install curl gnupg2 ca-certificates lsb-release debian-archive-keyring -y
apt install build-essential libpcre3-dev libssl-dev zlib1g-dev libgd-dev -y
```
* Update package lists: apt update
* Install additional dependencies: curl, gnupg2, ca-certificates, lsb-release, debian-archive-keyring, build-essential, libpcre3-dev, libssl-dev, zlib1g-dev, libgd-dev

### Step 11: Download and Prepare Nginx Modules
```
mkdir /opt/modules
cd /opt/modules/
git clone https://github.com/yaoweibin/nginx_upstream_check_module
git clone https://github.com/vozlt/nginx-module-vts
git clone https://github.com/openresty/headers-more-nginx-module

cd /opt/modules/
wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/v0.3.3.tar.gz
tar -xzvf v0.3.3.tar.gz
```
* Create directory for modules: mkdir /opt/modules
* Clone Nginx modules: nginx_upstream_check_module, nginx-module-vts, headers-more-nginx-module
* Download and extract ngx_devel_kit: wget and tar -xzvf

### Step 12: Build Nginx with Custom Modules
```
cd /data/f-stack/app/nginx-1.25.2

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

sed -i 's/ngx_http_upstream_check_peer_down(peer->check_index)/ngx_http_upstream_check_peer_down(i)/' /opt/modules/nginx-module-vts/src/ngx_http_vhost_traffic_status_display_json.c
sed -i 's/if (ngx_notify == NULL) {/if (0) {/' /data/f-stack/app/nginx-1.25.2/src/core/ngx_thread_pool.c

make -j$(nproc)
make install
```

* Navigate to Nginx directory: cd /data/f-stack/app/nginx-1.25.2
* Apply patch: patch -p1 --verbose < /opt/modules/nginx_upstream_check_module/check_1.20.1+.patch
* Configure Nginx with custom modules: ./configure ...
* Modify source code: sed -i ...
* Build and install Nginx: make -j$(nproc) and make install

### Step 13: Create Necessary Directories and Set Permissions
```
mkdir -p /var/lib/nginx/body
chmod 700 /var/lib/nginx/body
```

### Step 14: Verify Nginx Installation
```
mkdir -p /var/lib/nginx/body
chmod 700 /var/lib/nginx/body
```
* Create directory: mkdir -p /var/lib/nginx/body
* Set permissions: chmod 700 /var/lib/nginx/body

### Step 15: Verify Nginx Installation
```
nginx -V
```
* Verify Nginx installation: nginx -V
### Step 16: Configure F-Stack and Nginx

```
Step 16: Configure F-Stack and Nginx
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
```

* Create F-Stack configuration file: /etc/nginx/f-stack.conf
* Create Nginx configuration file: /etc/nginx/nginx.conf
* Test Nginx configuration: nginx -t

### Script Header and Variable Definitions
```
NIC=ens192
HUGEPAPGE=1024
```
- NIC=ens192: Defines the network interface card (NIC) to be used (ens192).
- HUGEPAPGE=1024: Defines the number of hugepages to be allocated (1024).

### Creating the F-Stack Startup Script
```cat > /etc/nginx/start.f-stack.sh << OEF
echo ${HUGEPAPGE} > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
modprobe uio
insmod /data/f-stack/dpdk/build/kernel/linux/igb_uio/igb_uio.ko
insmod /data/f-stack/dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on
ifconfig ${NIC} down
cd /data/f-stack/dpdk/usertools
python3 dpdk-devbind.py --bind=igb_uio ${NIC}
OEF
```
- echo ${HUGEPAPGE} > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages: Sets the number of hugepages to be allocated.
- modprobe uio: Loads the uio kernel module.
- insmod /data/f-stack/dpdk/build/kernel/linux/igb_uio/igb_uio.ko: Inserts the igb_uio kernel module.
- insmod /data/f-stack/dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on: Inserts the rte_kni kernel module with the carrier=on option.
- ifconfig ${NIC} down: Brings down the specified network interface (ens192).
- cd /data/f-stack/dpdk/usertools: Changes the current directory to /data/f-stack/dpdk/usertools.
- python3 dpdk-devbind.py --bind=igb_uio ${NIC}: Binds the specified network interface to the igb_uio driver using the dpdk-devbind.py script.

### Adding the Script to Crontab for Reboot
```
@reboot /etc/nginx/start.f-stack.sh > /var/log/start.f.stack.log 2>&1
```
- @reboot /etc/nginx/start.f-stack.sh > /var/log/start.f.stack.log 2>&1: Adds a crontab entry to run the start.f-stack.sh script at system reboot. The output of the script is redirected to /var/log/start.f.stack.log.

### Making the Script Executable
```
chmod +x /etc/nginx/start.f.stack.sh
```
- chmod +x /etc/nginx/start.f.stack.sh: Makes the start.f-stack.sh script executable.