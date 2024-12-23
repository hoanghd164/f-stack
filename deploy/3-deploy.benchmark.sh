apt update
apt install make unzip -y
apt install build-essential -y

git clone https://github.com/wg/wrk.git wrk
cd wrk
make

ulimit -n 65536
ulimit -u 65536

/etc/sysctl.conf

fs.file-max = 2097152
kernel.threads-max = 2097152

sysctl -p

./wrk -t10 -c1000 -d30s http://10.237.7.79