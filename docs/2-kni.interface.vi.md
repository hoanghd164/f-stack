## F-Stack KNI Interface
- Phần này hướng dẫn cách thiết lập một virtual NIC (veth0) để kernel có thể xử lý một phần lưu lượng thông qua interface KNI.  
- Interface KNI thường được bật để sử dụng một số tính năng thông qua Kernel mà vẫn giữ chung một địa chỉ IP cùng với F-Stack. Điều này mang lại sự đồng bộ, tránh phát sinh thêm một địa chỉ IP khác và cho phép sử dụng được các công cụ mà F-Stack chưa có như `ping`, `traceroute`, hoặc các dịch vụ cần xử lý thông qua Kernel.  
- Việc sử dụng KNI với IP chung giúp tối ưu hóa cấu hình network, trong đó F-Stack tiếp tục xử lý các gói tin có hiệu năng cao, còn KNI đảm bảo các gói tin đặc thù (như ICMP hoặc dịch vụ quản lý mạng) được chuyển giao về Kernel.  
- Tuy nhiên, cần đảm bảo cấu hình KNI và F-Stack đồng bộ, bao gồm IP, netmask và gateway, để tránh xung đột trong việc định tuyến.

### Topo
Hình này minh họa cấu trúc liên kết giữa User space, Kernel space và NIC khi sử dụng DPDK và KNI (Kernel Network Interface). 

![Sample Image](../images/kni.png "Example Title")

#### User Space
- App: Là ứng dụng do người dùng phát triển chạy trong User space.
- DPDK (Data Plane Development Kit): Là thư viện hỗ trợ xử lý gói tin trực tiếp từ NIC mà không cần thông qua Kernel. DPDK cung cấp các API để tương tác với phần cứng (NIC) và quản lý tài nguyên như bộ nhớ, CPU.
- Ring Buffers: Là cache dùng chung giữa DPDK và các thành phần khác như KNI. Gói tin được chuyển vào/ra giữa DPDK và Kernel qua Ring Buffers.

- Kernel Space:
  - TCP/IP Stack trong kernel chịu trách nhiệm xử lý các gói tin như ICMP, các giao thức HTTP hoặc gói tin từ các ứng dụng khác không sử dụng DPDK.
  - KNI Driver: Là driver đặc biệt của DPDK được triển khai trong Kernel, cho phép kết nối giữa User Space của DPDK và kernel. Gói tin từ App hoặc DPDK có thể được chuyển về Kernel thông qua KNI để xử lý bởi TCP/IP stack.
    
- NIC (Network Interface Card) là nơi nhận gói tin từ ngoài vào ứng dụng và truyền gói tin từ ứng dụng ra ngoài.

- Luồng xử lý:
    - Gói tin từ NIC được đẩy vào RX Queue.
      - Nếu gói tin được chỉ định cho DPDK, nó sẽ đi trực tiếp qua DPDK và đến App thông qua Ring Buffers.
      - Nếu gói tin cần Kernel xử lý, DPDK sẽ chuyển tiếp gói tin này qua KNI Driver đến TCP/IP Stack.

- Ưu điểm của KNI
  - Giữ khả năng sử dụng các công cụ quản lý mạng truyền thống thông qua TCP/IP stack của Kernel.
  - Phần lớn gói tin vẫn được xử lý qua DPDK để tối ưu hóa hiệu năng.
  - Cho phép giữ một IP chung giữa F-Stack (hoặc DPDK) và Kernel để tránh xung đột cấu hình.

### Thêm config này vào f-stack.conf
```
[kni]
enable=1
method=accept
tcp_port=22
udp_port=
```

- Virtual NIC này (thường là veth0) là cầu nối giữa kernel và F-Stack, cho phép kernel xử lý các gói tin được F-Stack chuyển về thông qua KNI.
- Bạn phải thiết lập thông tin (IP address, netmask, MAC address, route table) trên interface veth0.

# Khởi động lại fstack_ha.service
```
systemctl restart fstack_ha.service
```

### Kiểm tra lại danh sách inerface bằng lệnh ip a, sẽ xuất hiện thêm veth0, đây chính là kết quả của việc enable KNI.
```
root@node77:/etc/nginx# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:50:56:80:04:7b brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 10.237.7.77/24 brd 10.237.7.255 scope global ens160
       valid_lft forever preferred_lft forever
    inet6 fe80::250:56ff:fe80:47b/64 scope link
       valid_lft forever preferred_lft forever
4: veth0: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 00:50:56:80:c1:c2 brd ff:ff:ff:ff:ff:ff
```

### Đặt IP cho interface này, ip của KNI phải trùng với ip của f-stack.conf.
```
ifconfig veth0 10.237.7.79 netmask 255.255.255.0 broadcast 10.237.7.255
```

### Thêm các route bổ sung nếu cần.
```
route add default gw 10.237.7.1 dev veth0
```

### Kích hoạt interface KNI với tên veth0 nếu chưa có.
```
echo 1 > /sys/class/net/veth0/carrier
```

# Kiểm tra lại kết quả sau khi đặt IP cho KNI, veth0 đã xuất hiện với IP được đặt là 10.237.7.79.
```
root@node77:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens160: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:50:56:80:04:7b brd ff:ff:ff:ff:ff:ff
    altname enp3s0
    inet 10.237.7.77/24 brd 10.237.7.255 scope global ens160
       valid_lft forever preferred_lft forever
    inet6 fe80::250:56ff:fe80:47b/64 scope link
       valid_lft forever preferred_lft forever
8: veth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UNKNOWN group default qlen 1000
    link/ether 00:50:56:80:c1:c2 brd ff:ff:ff:ff:ff:ff
    inet 10.237.7.79/24 brd 10.237.7.255 scope global veth0
       valid_lft forever preferred_lft forever
    inet6 fe80::250:56ff:fe80:c1c2/64 scope link
       valid_lft forever preferred_lft forever
```

### Check port 22 vào ip của KNI từ client.
```
LAP60633s-MacBook-Pro:~ lap60633$ telnet 10.237.7.79 22
Trying 10.237.7.79...
Connected to 10.237.7.79.
Escape character is '^]'.
SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.7
```
### Kết quả mong đợi sẽ có một interface KNI (veth0) hoạt động như một port mạng ảo giữa kernel và F-Stack. Kernel có thể xử lý gói tin thông qua veth0 và chúng ta có thể dùng công cụ như tcpdump để giám sát lưu lượng trên interface này.