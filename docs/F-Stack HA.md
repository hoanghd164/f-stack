## Python Script for F-Stack High Availability
This script ensures high availability by continuously monitoring the VIP and associated services. If the VIP becomes unreachable, it attempts to take over the VIP by activating the interface. The script uses logging to provide detailed information about its actions and status.

### Configuration Section
```
VIP = "10.237.7.79" 
HEARTBEAT_INTERVAL = 10
INTERFACE_COMMAND = "/usr/sbin/nginx"
NC_TIMEOUT = 3
```
* VIP: The Virtual IP address that needs to be monitored.
* HEARTBEAT_INTERVAL: The interval in seconds between each check.
* INTERFACE_COMMAND: The command to activate the interface (in this case, starting nginx).
* NC_TIMEOUT: Timeout for the nc (netcat) command in seconds.

### Logging Function
```
def log(message):
    """Log messages to terminal."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    print(f"[{timestamp}] {message}")
```
* log: A helper function to print log messages with a timestamp.

### Check IP Reachability
```
def check_ip_reachability(ip, packets=4):
    """Check if an IP is reachable."""
    try:
        subprocess.check_output(["ping", "-c", str(packets), "-W", "1", ip], stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False
```
* check_ip_reachability: Uses the ping command to check if the given IP is reachable. Returns True if reachable, otherwise False.

### Activate Interface
```
def activate_interface():
    """Activate the F-Stack interface."""
    log("Activating interface...")
    result = os.system(INTERFACE_COMMAND)
    if result == 0:
        log("Interface activated successfully.")
        return True
    else:
        log("[ERROR] Failed to activate interface.")
        return False
```
* activate_interface: Executes the command to activate the interface (start nginx). Logs the result and returns True if successful, otherwise False.

### Deactivate Interface
```
def deactivate_interface():
    """Deactivate the F-Stack interface."""
    log("Deactivating interface...")
    os.system(f"{INTERFACE_COMMAND} -s stop")
```
* deactivate_interface: Executes the command to deactivate the interface (stop nginx).

### Main Function
```
def main():
    """Main function."""
    while True:
        vip_reachable = check_ip_reachability(VIP)

        if vip_reachable:
            log(f"VIP {VIP} and services are active.")
            time.sleep(HEARTBEAT_INTERVAL)
            continue

        log(f"[WARNING] VIP {VIP} or services are not reachable!")

        if not check_ip_reachability(VIP, packets=2):
            log("[WARNING] VIP is not reachable. Activating interface to take over VIP.")
            if not activate_interface():
                log("[ERROR] Failed to activate VIP. Will keep retrying.")
            else:
                log("[SUCCESS] Successfully activated VIP.")
        else:
            log("[WARNING] VIP is reachable. Trying later.")
                    
        time.sleep(HEARTBEAT_INTERVAL)
```
- main: The main loop that runs indefinitely.
  - Check VIP reachability: Uses check_ip_reachability to determine if the VIP is reachable.
  - If reachable: Logs that the VIP and services are active, then sleeps for the heartbeat interval before checking again.
  - If not reachable: Logs a warning and checks again with a reduced packet count.
    - If still not reachable: Attempts to activate the interface to take over the VIP.
      - If activation fails: Logs an error and retries.
      - If activation succeeds: Logs success.
  - If reachable on second check: Logs that the VIP is reachable and will try again later.

### Full code
```
import os
import subprocess
import time

# Configurations
VIP = "10.237.7.79" 
HEARTBEAT_INTERVAL = 10
INTERFACE_COMMAND = "/usr/sbin/nginx"
NC_TIMEOUT = 3

def log(message):
    """Log messages to terminal."""
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    print(f"[{timestamp}] {message}")

def check_ip_reachability(ip,packets=4):
    """Check if an IP is reachable."""
    try:
        subprocess.check_output(["ping", "-c", str(packets), "-W", "1", ip], stderr=subprocess.DEVNULL)
        return True
    except subprocess.CalledProcessError:
        return False

def activate_interface():
    """Activate the F-Stack interface."""
    log("Activating interface...")
    result = os.system(INTERFACE_COMMAND)
    if result == 0:
        log("Interface activated successfully.")
        return True
    else:
        log("[ERROR] Failed to activate interface.")
        return False

def deactivate_interface():
    """Deactivate the F-Stack interface."""
    log("Deactivating interface...")
    os.system(f"{INTERFACE_COMMAND} -s stop")

def main():
    """Main function."""
    while True:
        vip_reachable = check_ip_reachability(VIP)

        if vip_reachable:
            log(f"VIP {VIP} and services are active.")
            time.sleep(HEARTBEAT_INTERVAL)
            continue

        log(f"[WARNING] VIP {VIP} or services are not reachable!")

        if not check_ip_reachability(VIP, packets=2):
            log("[WARNING] VIP is not reachable. Activating interface to take over VIP.")
            if not activate_interface():
                log("[ERROR] Failed to activate VIP. Will keep retrying.")
            else:
                log("[SUCCESS] Successfully activated VIP.")
        else:
            log("[WARNING] VIP is reachable. Trying later.")
                    
        time.sleep(HEARTBEAT_INTERVAL)

if __name__ == "__main__":
    main()
```

### Creating the Systemd Service File
```
cat > /etc/systemd/system/fstack_ha.service << 'OEF'
[Unit]
Description=F-Stack High Availability Script
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=/home
ExecStart=/usr/bin/python3 /etc/nginx/fstack_ha
ExecStop=/usr/sbin/nginx -s stop
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
OEF
```

### Reloading Systemd and Enabling the Service
```
systemctl daemon-reload
systemctl enable fstack_ha.service
systemctl restart fstack_ha.service
systemctl status fstack_ha.service
```

### Debug.
```
journalctl -u fstack_ha.service -f -n 100
```