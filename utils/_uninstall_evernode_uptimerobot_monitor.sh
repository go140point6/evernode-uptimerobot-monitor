#!/bin/bash

# *** SETUP SOME VARIABLES THAT THIS SCRIPT NEEDS ***

# Set Colour Vars
GREEN='\033[0;32m'
#RED='\033[0;31m'
RED='\033[0;91m'  # Intense Red
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
BLUE='\033[0;94m'
NC='\033[0m' # No Color

# Find out who is running this script
if [ "$(id -u)" -ne 0 ]; then
    # Regular user without invoking sudo
    ORIG_USER=$(getent passwd "$(id -u)" | cut -d: -f1)
    ORIG_HOME=$(getent passwd "$(id -u)" | cut -d: -f6)
else
    if [ -n "$SUDO_USER" ]; then
        # Regular user with sudo
        ORIG_USER=$(getent passwd "$SUDO_USER" | cut -d: -f1)
        ORIG_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        # Root user without sudo
        ORIG_USER=$(getent passwd "$(id -u)" | cut -d: -f1)
        ORIG_HOME=$(getent passwd "$(id -u)" | cut -d: -f6)
    fi
fi

echo -e "$ORIG_USER"
echo -e "$ORIG_HOME"

# Authenticate sudo perms before script execution to avoid timeouts or errors.
# Extend sudo timeout to 20 minutes, instead of default 5 minutes.
if sudo -l > /dev/null 2>&1; then
    TMP_FILE01=$(mktemp)
    TMP_FILENAME01=$(basename $TMP_FILE01)
    echo "Defaults:$USER_ID timestamp_timeout=20" > $TMP_FILE01
    sudo sh -c "cat $TMP_FILE01 > /etc/sudoers.d/$TMP_FILENAME01"
else
    echo "The user $USER_ID doesn't appear to have sudo privledges, add to sudoers or run as root."
    exit 1
fi

# Get the absolute path of the directories
MONITOR_DIR=$HOME/evernode-uptimerobot-monitor
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
VARS_FILE=evernode_monitor.vars
source $SCRIPT_DIR/$VARS_FILE

echo -e "${RED}#########################################################################"
echo -e "${RED}#########################################################################"
echo -e "${RED}"
echo -e "${RED}!!  WARNING  !!${NC} Evernode UptimeRobot Monitor Uninstall ${RED}!!  WARNING  !!${NC}"
echo -e "${RED}"
echo -e "${RED}       This script will remove the Evernode UptimeRobot Monitor.${NC}"
echo -e "${RED}"
echo -e "${GREEN}** NOTE **${NC} Evernode installation, if any, ${GREEN}will not${NC} be touched ${GREEN}** NOTE **${NC}"  
echo -e "${RED}#########################################################################"
echo -e "${RED}#########################################################################${NC}"
echo -e
echo -e

# Verify to proceed and timeout if no response.
CHECK_PASSWD=false
    while true; do
        read -t10 -r -p "Are you sure you want to continue? (Y/n) " _input
        if [ $? -gt 128 ]; then
            #clear
            echo
            echo "Timed out waiting for user response - quitting..."
            exit 0
        fi
        case $_input in
            [Yy][Ee][Ss]|[Yy]* )
                break
                ;;
            [Nn][Oo]|[Nn]* ) 
                exit 0
                ;;
            * ) echo "Please answer (y)es or (n)o.";;
        esac
    done

# Ensure that SCRIPT_DIR and MONITOR_DIR are set
if [[ -z "$SCRIPT_DIR" || -z "$MONITOR_DIR" ]]; then
    echo -e "SCRIPT_DIR or MONITOR_DIR is not set. Exiting to avoid accidental deletion."
    exit 1
fi

# Define the directories
UR_SERVICE_DIR="$SCRIPT_DIR/service-files"
UR_SERVICE_UNIT_DIR="$SCRIPT_DIR/service-units"

# Ensure that UR_SERVICE_DIR and UR_SERVICE_UNIT_DIR are within SCRIPT_DIR to prevent unintended deletion
if [[ "$UR_SERVICE_DIR" != "$SCRIPT_DIR/service-files" || "$UR_SERVICE_UNIT_DIR" != "$SCRIPT_DIR/service-units" ]]; then
    echo -e "The directories to be removed are not within the SCRIPT_DIR. Exiting to avoid accidental deletion."
    exit 1
fi

# Remove firewall configs if UFW in use
if sudo systemctl list-unit-files --type=service | grep -q 'ufw.service'; then
  if sudo systemctl is-active --quiet ufw.service; then
    echo -e "UFW is installed and running. This is ${GREEN}GOOD${NC}. Proceeding with UFW port config removal..."
    # Loop through each file in the service-units directory
    for service_file in "$UR_SERVICE_UNIT_DIR"/uptimeRobot-24*.service; do
      # Extract the port number from the filename
      port=$(echo "$service_file" | grep -oP '(?<=uptimeRobot-24)\d{3}(?=.service)')

      if [[ -n $port ]]; then
      # Remove port configs
        sudo ufw delete allow "24$port/tcp"
        echo -e "Firewall rule removed for port 24$port/tcp"
        sleep 1s
      else
        echo "No valid port found in $service_file"
      fi
    done
    sudo ufw status verbose
  else
      echo -e "UFW is installed but not running. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW configuration..."
  fi
else
  echo -e "UFW is not installed. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW configuration..."
fi

# Read the CSV file to gather the ports for removing symlinks
MY_NODES="$MONITOR_DIR/data/myNodes.csv"
echo >> "$MY_NODES"

if [[ ! -f "$MY_NODES" ]]; then
    echo -e "The CSV file $MY_NODES does not exist. Exiting."
    exit 1
fi

# Read the CSV file line by line, skipping header and empty lines
{
    read # skip header
    while IFS=, read -r address host nick port gas activeOk leaseAmountOk leaseAmountRatioOk maxInstancesOk hostReputationOk; do
        if [[ -n $address && -n $host && -n $nick && -n $port && -n $gas && -n $activeOk && -n $leaseAmountOk && -n $leaseAmountRatioOk && -n $maxInstancesOk && -n $hostReputationOk ]]; then
            # Stop and disable the service
            sudo systemctl stop uptimeRobot-$port.service
            sudo systemctl disable uptimeRobot-$port.service
            # Remove the symbolic link in /etc/systemd/system
            sudo rm -vf /etc/systemd/system/uptimeRobot-$port.service
            sleep 1s
        fi
    done
} < "$MY_NODES"

# Ensure that the directories exist before attempting to remove them
if [[ -d "$UR_SERVICE_DIR" ]]; then
    rm -rvf "$UR_SERVICE_DIR"
else
    echo -e "Directory $UR_SERVICE_DIR does not exist. Skipping removal."
fi

if [[ -d "$UR_SERVICE_UNIT_DIR" ]]; then
    rm -rvf "$UR_SERVICE_UNIT_DIR"
else
    echo -e "Directory $UR_SERVICE_UNIT_DIR does not exist. Skipping removal."
fi

# Reload systemd manager configuration
sudo systemctl daemon-reload

# Debugging: Print confirmation
echo -e
echo -e "Service files and units have been removed, and systemd configuration reloaded."

# Remove the .env
if [ -e "$MONITOR_DIR/.env" ]; then
  echo -e
  rm -rfv $MONITOR_DIR/.env
fi

# Remove pm2 first
# Remove pm2, pm2 config/log files, and startup process
echo -e "Removing pm2 and startup process..."
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 unstartup systemd -u $ORIG_USER --hp $ORIG_HOME
sudo npm remove -g pm2
if [ -e "$ORIG_HOME/.pm2" ]; then
    echo -e
    rm -rfv $ORIG_HOME/.pm2
fi

# Then remove node
ver() {
    printf "%03d%03d%03d" $(echo "$1" | tr '.' ' ')
}

if command -v node >/dev/null 2>&1; then
NODE_VERSION=$(node -v | sed 's/v//')
    if [ $(ver "$NODE_VERSION") -ge $(ver "18.0.0") ]; then
        sudo apt remove --purge -y nodejs && sudo apt autoremove -y
    else
        echo -e "Node not currently installed."
    fi
fi

# Clean up any left over npm junk
if [ -e "/usr/lib/node_modules" ]; then
    echo -e
    sudo rm -rfv /usr/lib/node_modules
fi

# Remove logrotate files
if [ -e "/etc/logrotate.d/evernode-monitor-logs" ]; then
    echo -e
    sudo rm -rfv /etc/logrotate.d/evernode-monitor-logs
fi

# Remove user from sudoers
TMP_FILE07=$(mktemp)
SUDOERS_LINE="$ORIG_USER ALL=(ALL:ALL) NOPASSWD:/usr/bin/systemctl"
sudo cp /etc/sudoers $TMP_FILE07
sudo sed -i "\|$SUDOERS_LINE|d" $TMP_FILE07
if sudo visudo -c -f $TMP_FILE07; then
  sudo cp $TMP_FILE07 /etc/sudoers
  echo -e "User removed from sudoers."
else
  echo -e "Error: visudo check failed. Changes not applied."
fi

# Remove log files
if [ -e "$MONITOR_DIR/logs" ]; then
    echo -e
    rm -rfv "$MONITOR_DIR/logs"
fi

echo -e
echo -e "${GREEN}#########################################################################${NC}"
echo -e "${GREEN}#########################################################################${NC}"
echo -e
echo -e "${GREEN}   **${NC} Evernode UptimeRobot Monitor uninstalled ${GREEN}**${NC}"
echo -e
echo -e "${GREEN}#########################################################################${NC}"
echo -e "${GREEN}#########################################################################${NC}"
echo -e
exit 0