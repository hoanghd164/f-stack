## F-Stack tools deploy
### Setting the PKG_CONFIG_PATH Environment Variable
```
export PKG_CONFIG_PATH=/usr/lib64/pkgconfig:/usr/local/lib64/pkgconfig:/usr/lib/pkgconfig
```
* export PKG_CONFIG_PATH: This command sets the PKG_CONFIG_PATH environment variable to include multiple directories where pkg-config will look for package configuration files. This is necessary for the build process to locate the required libraries and their configurations.

### Listing Contents of the Tools Directory
```
ls -l /data/f-stack/tools
ls -l /data/f-stack/tools/ifconfig/
```
- ls -l /data/f-stack/tools: Lists the contents of the /data/f-stack/tools directory in long format, showing detailed information about each file and directory.
- ls -l /data/f-stack/tools/ifconfig/: Lists the contents of the /data/f-stack/tools/ifconfig/ directory in long format, showing detailed information about each file and directory.

### Building and Installing Tools
```
cd /data/f-stack/tools
make
make install
```

### Listing Contents of the Installed Tools Directory
```
shell> ls -l /usr/local/bin/f-stack/
total 366504
-rwxr-xr-x 1 root root 34200336 Dec 19 00:02 arp
-rwxr-xr-x 1 root root 34173376 Dec 19 00:02 ifconfig
-rwxr-xr-x 1 root root 34310528 Dec 19 00:02 ipfw
-rwxr-xr-x 1 root root 33979656 Dec 19 00:02 knictl
-rwxr-xr-x 1 root root 34017512 Dec 19 00:02 ndp
-rwxr-xr-x 1 root root 34518144 Dec 19 00:02 netstat
-rwxr-xr-x 1 root root 34078488 Dec 19 00:02 ngctl
-rwxr-xr-x 1 root root 34023120 Dec 19 00:02 route
-rwxr-xr-x 1 root root 34011472 Dec 19 00:02 sysctl
-rwxr-xr-x 1 root root 33983448 Dec 19 00:02 top
-rwxr-xr-x 1 root root 33983496 Dec 19 00:02 traffic
```

### Example running the ifconfig Tool
```
shell> cd /usr/local/bin/f-stack/
shell> ./ifconfig f-stack-0
f-stack-0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> metric 0 mtu 1500
        ether 0:50:56:80:2:b5
        inet 10.237.7.79 netmask 0xffffff00 broadcast 10.237.7.255
        inet6 fe80::250:56ff:fe80:2b5 prefixlen 64 scopeid 0x2
        nd6 options=23<PERFORMNUD,ACCEPT_RTADV,AUTO_LINKLOCAL>
```
- ./ifconfig: Runs the ifconfig tool to display the network configuration.