################################
####### CHANGE PLAN ############
################################
# MARIADB_IP_NODE1: 10.237.7.77
# MARIADB_IP_NODE2: 10.237.7.78
# KEEPALIVED_VIP: 10.237.7.36
# GRABD_IP: 10.10.16.16
# GRABD_PORT: 4567
# MARIADB_VERSION: 10.11
# DEPLOY: MARIADB GALERA CLUSTER ACTIVE-ACTIVE, KEEPALIVED, GRABD ON DOCKER CONTAINER

### PRE-CHANGE
# Check VIP 10.237.7.36 not reachable from VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241 and VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-242
root@VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-242:~# ping -c 4 10.237.7.36
PING 10.237.7.36 (10.237.7.36) 56(84) bytes of data.
From 10.237.7.78 icmp_seq=1 Destination Host Unreachable
From 10.237.7.78 icmp_seq=2 Destination Host Unreachable
From 10.237.7.78 icmp_seq=3 Destination Host Unreachable
From 10.237.7.78 icmp_seq=4 Destination Host Unreachable

--- 10.237.7.36 ping statistics ---
4 packets transmitted, 0 received, +4 errors, 100% packet loss, time 3078ms

# Installation of Docker on all nodes
apt-get update
apt-get install ca-certificates curl gnupg lsb-release -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install docker-ce docker-ce-cli containerd.io -y
chmod 666 /var/run/docker.sock

curl -L "https://github.com/docker/compose/releases/download/v2.6.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose -v

# Configuration Proxy for Docker on all nodes
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/http-proxy.conf << 'OEF'
[Service]
Environment="HTTP_PROXY=http://10.237.7.250:3128" "HTTPS_PROXY=http://10.237.7.250:3128" "NO_PROXY=localhost,127.0.0.1,docker-registry.somecorporation.com"
OEF
systemctl daemon-reload
systemctl restart docker

# Create folder for MySQL on node1 and node2
mkdir -p /opt/mysql
mkdir -p /opt/mysql/data
mkdir -p /opt/mysql/backup

# Move to MySQL folder on node1 and node2
cd /opt/mysql

# Create environment file for MySQL on all nodes
cat > /opt/mysql/backup/.env << 'OEF'
MARIADB_ROOT_PASSWORD=lsMz0cb0eLGAMESg
MARIADB_USER=sw_auth_2
MARIADB_PASSWORD=wuARxZTUT4eU4yGQ
MARIADB_DATABASE=keystone_sw_auth_2
MARIADB_IP_NODE1=10.237.7.77
MARIADB_IP_NODE2=10.237.7.78
KEEPALIVED_VIP=10.237.7.36/24
KEEPALIVED_PASSWORD=SnsSt0rageH4N
KEEPALIVED_INTERFACE=ens160
OEF

cp /opt/mysql/backup/.env /opt/mysql/.env
source /opt/mysql/backup/.env

# Create 50-server.cnf file for MySQL on all nodes
cat > /opt/mysql/50-server.cnf << 'OEF'
[server]
[mysqld]
pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr
expire_logs_days        = 10
character-set-server  = utf8mb4
collation-server      = utf8mb4_general_ci

# Load plugins
plugin_load_add = server_audit
plugin_load_add = simple_password_check

# Audit settings
server_audit_events = connect,query_dcl,query_ddl
server_audit_logging = ON
server_audit_output_type = FILE

# Password check settings
simple_password_check_other_characters = 1
simple_password_check_minimal_length = 14
simple_password_check_digits = 1
simple_password_check_letters_same_case = 1
strict_password_validation = ON
simple_password_check = OFF

[embedded]
[mariadb]
[mariadb-10.6]
OEF

# Create galera.cnf file for MySQL on first node
cat > /opt/mysql/galera.cnf << OEF
[galera]
wsrep_on                 = ON
wsrep_cluster_name       = "MariaDB Galera Cluster"
wsrep_provider           = /usr/lib/galera/libgalera_smm.so
wsrep_cluster_address    = "gcomm://" # This is the default value. Change it to the IP address of the first node.
# wsrep_cluster_address    = "gcomm://${MARIADB_IP_NODE1},${MARIADB_IP_NODE2}"
binlog_format            = row
default_storage_engine   = InnoDB
innodb_autoinc_lock_mode = 2
bind-address = 0.0.0.0
wsrep_node_address="${MARIADB_IP_NODE1}"
OEF

# Create galera.cnf file for MySQL on second node
cat > /opt/mysql/galera.cnf << OEF
[galera]
wsrep_on                 = ON
wsrep_cluster_name       = "MariaDB Galera Cluster"
wsrep_provider           = /usr/lib/galera/libgalera_smm.so
wsrep_cluster_address    = "gcomm://${MARIADB_IP_NODE1},${MARIADB_IP_NODE2}"
binlog_format            = row
default_storage_engine   = InnoDB
innodb_autoinc_lock_mode = 2
bind-address = 0.0.0.0
wsrep_node_address="${MARIADB_IP_NODE2}"
OEF

# Create docker-compose.yml file for MySQL on all nodes
cat > /opt/mysql/docker-compose.yml << 'OEF'
version: "3"
services: 
 mariadb:
   image: mariadb:10.11
   container_name: mariadb
   network_mode: host
   restart: always
   env_file: .env
   environment:
    - MARIADB_USER=${MARIADB_USER}
    - MARIADB_PASSWORD=${MARIADB_PASSWORD}
    - MARIADB_DATABASE=${MARIADB_DATABASE}
    - MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD}
   volumes:
    - /opt/mysql/data:/var/lib/mysql
    - /opt/mysql/backup:/opt/mysql/backup
    - /opt/mysql/galera.cnf:/etc/mysql/mariadb.conf.d/galera.cnf
    - /opt/mysql/50-server.cnf:/etc/mysql/mariadb.conf.d/50-server.cnf
   cap_add:
    - all
OEF

# Deploy MySQL on first node
docker-compose up -d

# Check wsrep_cluster_size on first node
shell> docker-compose exec mariadb mysql -u root -p${MARIADB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
+--------------------+-------+
| Variable_name      | Value |
+--------------------+-------+
| wsrep_cluster_size | 1     |
+--------------------+-------+

# Deploy MySQL on second node
docker-compose up -d

# Check wsrep_cluster_size on any node
shell> docker-compose exec mariadb mysql -u root -p${MARIADB_ROOT_PASSWORD} -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
+--------------------+-------+
| Variable_name      | Value |
+--------------------+-------+
| wsrep_cluster_size | 2     |
+--------------------+-------+

# Create folder for MySQL on Garbd node
mkdir -p /opt/mysql

# Move to MySQL folder on Garbd node
cd /opt/mysql

# Create Dockerfile for Garbd on other node
cat > /opt/mysql/Dockerfile << 'EOF'
# Use an official MariaDB as a parent image
FROM mariadb:10.11

# Set up proxy arguments
ARG http_proxy
ARG https_proxy
ARG no_proxy

# Set environment variables for the proxy
ENV http_proxy=${http_proxy}
ENV https_proxy=${https_proxy}
ENV no_proxy=${no_proxy}

# Update the package list and install necessary packages
RUN apt-get update && \
    apt-get install -y galera-4 galera-arbitrator-4

# Create necessary directories and files, set permissions
RUN mkdir -p /var/log/ && \
    touch /var/log/garbd.log && \
    chown nobody:nogroup /var/log/garbd.log && \
    chmod 644 /var/log/garbd.log
EOF

# Create docker-compose.yml file for Garbd
cat > /opt/mysql/garbd-docker-compose.yml << OEF
version: "3"
services: 
  garbd: 
    image: garbd:latest
    container_name: garbd
    network_mode: host
    restart: always
    command: >
      garbd
      --address "gcomm://${MARIADB_IP_NODE1}:4567,${MARIADB_IP_NODE2}:4567"
      --group "MariaDB Galera Cluster"
      --options "pc.wait_prim=no"
      --log "/var/log/garbd.log"
OEF
 
# Build Garbd
docker build --build-arg http_proxy=http://10.237.7.250:3128 --build-arg https_proxy=http://10.237.7.250:3128 --build-arg no_proxy="localhost,127.0.0.1,10.237.7.0/24" -t garbd .

# Deploy Garbd
docker-compose up -d

# Check wsrep_cluster_size on node1 or node2
shell> docker-compose exec mariadb mysql -u root -p"lsMz0cb0eLGAMESg" -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
+--------------------+-------+
| Variable_name      | Value |
+--------------------+-------+
| wsrep_cluster_size | 3     |
+--------------------+-------+

## Install Keepalived on VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241 and VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-242
## On VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241
apt-get install linux-headers-$(uname -r)
apt-get update
apt-get install keepalived -y

cat > /etc/keepalived/keepalived.conf << OEF
global_defs {
        script_user root
        enable_script_security
}

vrrp_script check_process {
    script "/usr/bin/nc -zv 127.0.0.1 3306"
    interval 2
    timeout 3
    fall 2
    rise 2
}

# Virtual interface
# The priority specifies the order in which the assigned interface to take over in a failover
vrrp_instance VI_240 {
        state MASTER
        interface ${KEEPALIVED_INTERFACE}
        virtual_router_id 240
        priority 200
        advert_int 2

        authentication {
                auth_type PASS
                auth_pass ${KEEPALIVED_PASSWORD}
        }

    unicast_src_ip ${MARIADB_IP_NODE1}
    unicast_peer {
            ${MARIADB_IP_NODE2}
    }

        # The virtual ip address shared between the two loadbalancers
        virtual_ipaddress {
                ${KEEPALIVED_VIP} dev ${KEEPALIVED_INTERFACE}
        }

        track_script {
                check_process
        }
}
OEF

# On VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-242
cat > /etc/keepalived/keepalived.conf << OEF
global_defs {
        script_user root
        enable_script_security
}

vrrp_script check_process {
    script "/usr/bin/nc -zv 127.0.0.1 3306"
    interval 2
    timeout 3
    fall 2
    rise 2
}

# Virtual interface
# The priority specifies the order in which the assigned interface to take over in a failover
vrrp_instance VI_240 {
        state BACKUP
        interface ${KEEPALIVED_INTERFACE}
        virtual_router_id 240
        priority 100
        advert_int 2

        authentication {
                auth_type PASS
                auth_pass ${KEEPALIVED_PASSWORD}
        }

        unicast_src_ip ${MARIADB_IP_NODE2}
        unicast_peer {
            ${MARIADB_IP_NODE1}
        }

        virtual_ipaddress {
                ${KEEPALIVED_VIP} dev ${KEEPALIVED_INTERFACE}
        }

        track_script {
                check_process
        }
}
OEF

## Restart, enable and check the status of Keepalived on VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241 and VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-242
systemctl restart keepalived
systemctl enable keepalived
systemctl status keepalived

## Check the status of Keepalived on VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241 and VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-242
ip a | grep ${KEEPALIVED_VIP}

# Enter the MariaDB container on VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241
docker exec -it mariadb bash

# Source the environment file
source /opt/mysql/backup/.env

# Install MariaDB client on VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241
apt install mariadb-client-core-10.6 -y

# Restore the backup of keystone_sw_auth_2 on VIP 
mysql -h $(echo ${KEEPALIVED_VIP} | cut -d'/' -f1) -u sw_auth_2 -p${MARIADB_PASSWORD} ${MARIADB_DATABASE} < /opt/mysql/backup/keystone_sw_auth_2.sql

# Verify the connection to MariaDB olsn VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-241 and VSTOR-SWIFT-HAN01-PHYS-KEYSTONE-242 from VIP 
mysql -h $(echo ${KEEPALIVED_VIP} | cut -d'/' -f1) -u sw_auth_2 -p${MARIADB_PASSWORD} -D ${MARIADB_DATABASE} -e "SELECT COUNT(*) FROM user;"
+----------+
| COUNT(*) |
+----------+
|     1349 |
+----------+

# Create again galera.cnf file for MySQL on first node
cat > /opt/mysql/galera.cnf << OEF
[galera]
wsrep_on                 = ON
wsrep_cluster_name       = "MariaDB Galera Cluster"
wsrep_provider           = /usr/lib/galera/libgalera_smm.so
# wsrep_cluster_address    = "gcomm://" # This is the default value. Change it to the IP address of the first node.
wsrep_cluster_address    = "gcomm://${MARIADB_IP_NODE1},${MARIADB_IP_NODE2}"
binlog_format            = row
default_storage_engine   = InnoDB
innodb_autoinc_lock_mode = 2
bind-address = 0.0.0.0
wsrep_node_address="${MARIADB_IP_NODE1}"
OEF

## ROLLBACK
cd /opt/mysql
docker-compose down

systemctl stop keepalived
systemctl stop docker

systemctl disable keepalived
systemctl disable docker

systemctl status docker
systemctl status keepalived

apt update
apt install pkg-config libmysqlclient-dev -y
apt-get install python3-tk
pip install Flask-MySQLDB