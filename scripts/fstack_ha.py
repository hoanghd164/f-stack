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