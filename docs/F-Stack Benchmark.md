## Benchmark F-Stack
This script updates the package lists and installs necessary dependencies for building software. It then clones the wrk benchmarking tool from GitHub and builds it. The script sets system limits for open file descriptors and user processes, configures kernel parameters for maximum file handles and threads, and applies these changes. Finally, it runs the wrk benchmarking tool to test the performance of the server at the specified URL.
### Updating and Installing Dependencies
```
apt update
apt install make unzip -y
apt install build-essential -y
```

### Cloning and Building wrk
```
git clone https://github.com/wg/wrk.git wrk
cd wrk
make
```

### Setting System Limits
```
ulimit -n 65536
ulimit -u 65536
```

### Configuring System Parameters
- Edit /etc/sysctl.conf to configure kernel parameters at runtime.
```
fs.file-max = 2097152
kernel.threads-max = 2097152
```

- Applying System Parameter Changes
- Loads the kernel parameters from /etc/sysctl.conf and applies them.
```
sysctl -p
```

### Running the Benchmark
```
./wrk -t10 -c1000 -d30s http://10.237.7.79
```
* ./wrk -t10 -c1000 -d30s http://10.237.7.79: Runs the wrk benchmarking tool with the following parameters:
  * -t10: Uses 10 threads.
  * -c1000: Maintains 1000 open connections.
  * -d30s: Runs the benchmark for 30 seconds.
  * http://10.237.7.79: The target URL for the benchmark.

### Benchmark
- System Information
```
shell> dmidecode -t1
# dmidecode 3.3
Getting SMBIOS data from sysfs.
SMBIOS 2.7 present.

Handle 0x0001, DMI type 1, 27 bytes
System Information
        Manufacturer: VMware, Inc.
        Product Name: VMware Virtual Platform
        Version: None
        Serial Number: VMware-42 00 e0 14 58 c1 41 d7-50 b6 ff cd 24 c0 41 87
        UUID: 14e00042-c158-d741-50b6-ffcd24c04187
        Wake-up Type: Power Switch
        SKU Number: Not Specified
        Family: Not Specified
```

- Memory.
```
shell> free -h
               total        used        free      shared  buff/cache   available
Mem:           7.8Gi       2.9Gi       4.1Gi       1.0Mi       732Mi       4.6Gi
Swap:          4.0Gi        67Mi       3.9Gi
```

- CPU.
```
processor       : 3
vendor_id       : GenuineIntel
cpu family      : 6
model           : 79
model name      : Intel(R) Xeon(R) CPU E5-2690 v4 @ 2.60GHz
```

- NIC.
```
ethtool ens192 | grep -E "Link detected|Speed"
        Speed: 10000Mb/s
        Link detected: yes
```

#### Kernel
```
root@node78:~/wrk# ./wrk -t10 -c1000 -d30s http://10.237.7.78
Running 30s test @ http://10.237.7.78
  10 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     8.25ms    7.28ms  76.76ms   84.81%
    Req/Sec    14.33k     2.55k   28.16k    65.85%
  4275390 requests in 30.07s, 3.42GB read
Requests/sec: 142183.73
Transfer/sec:    116.47MB
```

#### DPDK
```
root@node78:~/wrk# ./wrk -t10 -c1000 -d30s http://10.237.7.79
Running 30s test @ http://10.237.7.79
  10 threads and 1000 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    21.73ms   52.38ms 690.81ms   88.45%
    Req/Sec    38.10k     4.25k   63.18k    76.79%
  11383918 requests in 30.03s, 8.11GB read
Requests/sec: 379046.45
Transfer/sec:    276.54MB
```