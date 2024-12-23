#!/bin/bash
NIC=ens192
HUGEPAPGE=1024
cat > /etc/nginx/start.f-stack.sh << OEF
echo ${HUGEPAPGE} > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
modprobe uio
insmod /data/f-stack/dpdk/build/kernel/linux/igb_uio/igb_uio.ko
insmod /data/f-stack/dpdk/build/kernel/linux/kni/rte_kni.ko carrier=on
ifconfig ${NIC} down
cd /data/f-stack/dpdk/usertools
python3 dpdk-devbind.py --bind=igb_uio ${NIC}
OEF

@reboot /etc/nginx/start.f-stack.sh > /var/log/start.f-stack.log 2>&1
chmod +x /etc/nginx/start.f-stack.sh