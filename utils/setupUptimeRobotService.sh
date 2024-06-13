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
    FUNC_EXIT_ERROR
fi

# Get the absolute path of the directories
MONITOR_DIR=$HOME/evernode-uptimerobot-monitor
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
VARS_FILE=evernode_monitor.vars
source $SCRIPT_DIR/$VARS_FILE


FUNC_VERIFY() {
    CHECK_PASSWD=false
    while true; do
        read -t10 -r -p "Are you sure you want to continue? (Y/n) " _input
        if [ $? -gt 128 ]; then
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
}


FUNC_PKG_CHECK() {
    echo
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    echo -e "${GREEN}## ${YELLOW}Check/install necessary packages... ${NC}"
    echo     

    sudo apt update
    for i in "${SYS_PACKAGES[@]}"
    do
        hash $i &> /dev/null
        if [ $? -eq 1 ]; then
            echo >&2 "package "$i" not found. installing..."
            sudo apt install -y "$i"
        else
            echo "packages "$i" exist, proceeding to next..."
        fi
    done
    echo -e "${GREEN}## ALL PACKAGES INSTALLED.${NC}"
    echo 
    echo -e "${GREEN}#########################################################################${NC}"
    echo
    sleep 2s
}


FUNC_INSTALL_SERVICE() {
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Install uptimeRobot.service for each node... ${NC}"
    echo -e

    MY_NODES=$MONITOR_DIR/data/myNodes.csv
    echo >> "$MY_NODES"

    # Directory to store the service and unit files
    UR_SERVICE_DIR="$SCRIPT_DIR/service-files"
    UR_SERVICE_UNIT_DIR="$SCRIPT_DIR/service-units"

    # Create the directories if they don't exist
    mkdir -p "$UR_SERVICE_DIR"
    mkdir -p "$UR_SERVICE_UNIT_DIR"

    URSERVICE_PY_TEMPLATE=$SCRIPT_DIR/uptimeRobotService.py.template
    URSERVICE_UNIT_TEMPLATE=$SCRIPT_DIR/uptimeRobotService.unit.template

    # Read the CSV file line by line, skipping header and empty lines
    {
        read # skip header
        while IFS=, read -r address host nick port gas activeOk leaseAmountOk leaseAmountRatioOk maxInstancesOk hostReputationOk; do
            if [[ -n $address && -n $host && -n $nick && -n $port && -n $gas && -n $activeOk && -n $leaseAmountOk && -n $leaseAmountRatioOk && -n $maxInstancesOk && -n $hostReputationOk ]]; then
                UPTIME_ROBOT_SERVICE_FILE="$UR_SERVICE_DIR/uptimeRobotService-$port.py"
                UPTIME_ROBOT_SERVICE_UNIT_FILE="$UR_SERVICE_UNIT_DIR/uptimeRobot-$port.service"
                sudo sed "s|{{PORT}}|$port|" "$URSERVICE_PY_TEMPLATE" > "$UPTIME_ROBOT_SERVICE_FILE"
                sudo sed -e "s|{{DIR}}|$UR_SERVICE_DIR|" -e "s|{{PORT}}|$port|" $URSERVICE_UNIT_TEMPLATE > $UPTIME_ROBOT_SERVICE_UNIT_FILE
                chmod 755 "$UPTIME_ROBOT_SERVICE_FILE"
                sudo ln -sfn $UPTIME_ROBOT_SERVICE_UNIT_FILE /etc/systemd/system/uptimeRobot-$port.service
                sudo systemctl enable uptimeRobot-$port.service
                sudo systemctl start uptimeRobot-$port.service
                sudo systemctl status uptimeRobot-$port.service
                sleep 1s
            fi
        done
    } < "$MY_NODES"

    # Debugging: Print number of service files created
    NUM_FILES_CREATED=$(find "$UR_SERVICE_DIR" -type f | wc -l)
    NUM_UNITS_CREATED=$(find "$UR_SERVICE_UNIT_DIR" -type f | wc -l)
    echo -e "Number of service files created: $NUM_FILES_CREATED"
    echo -e "Number of service-unit files created: $NUM_UNITS_CREATED"
    sudo systemctl daemon-reload
    sleep 2s
}


FUNC_FIREWALL_CONFIG(){
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: UFW Firewall... ${NC}"
    echo -e

    echo -e "${GREEN}## ${YELLOW}Step 1. Check if UFW is in use... ${NC}"
    echo -e

    if sudo systemctl list-unit-files --type=service | grep -q 'ufw.service'; then
        if sudo systemctl is-active --quiet ufw.service; then
            echo -e "UFW is installed and running. This is ${GREEN}GOOD${NC}. Proceeding with UFW configuration..."
            echo -e
            echo -e "${GREEN}## ${YELLOW}Step 2. Add monitoring ports... ${NC}"
            echo -e

            # Loop through each file in the service-units directory
            for service_file in "$UR_SERVICE_UNIT_DIR"/uptimeRobot-24*.service; do
            # Extract the port number from the filename
                port=$(echo "$service_file" | grep -oP '(?<=uptimeRobot-24)\d{3}(?=.service)')
    
                if [[ -n $port ]]; then
                    # Allow the port through the firewall
                    sudo ufw allow "24$port/tcp"
                    echo -e "Firewall rule added for port 24$port/tcp"
                    sleep 1s
                else
                    echo -e "No valid port found in $service_file"
                fi
            done
            sudo ufw status verbose

            echo -e
            echo -e "${GREEN}## ${YELLOW}Step 3. Change UFW logging to [ufw.log only]... ${NC}"
            echo -e
            sudo sed -i -e 's/\#& stop/\& stop/g' /etc/rsyslog.d/20-ufw.conf
            sudo cat /etc/rsyslog.d/20-ufw.conf | grep '& stop'
            echo -e "Logging changed to [ufw.log only] if you see '& stop' as the output above."
        else
            echo -e "UFW is installed but not running. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW configuration..."
        fi
    else
        echo -e "UFW is not installed. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW configuration..."
    fi
}


FUNC_CREATE_ENV(){
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: Set up the .env file if not present... ${NC}"
    echo -e

    TMP_FILE04=$(mktemp)
    sed -n '/## BEGIN - DO NOT CHANGE THIS LINE/,/## END - DO NOT CHANGE THIS LINE/p' $SCRIPT_DIR/$VARS_FILE > $TMP_FILE04
    sed -i '/## BEGIN - DO NOT CHANGE THIS LINE/d' $TMP_FILE04
    sed -i '/## END - DO NOT CHANGE THIS LINE/d' $TMP_FILE04

    # Move the temp file to the desired location
    sh -c "cat $TMP_FILE04 > $MONITOR_DIR/.env"
    echo -e "OK"
}


FUNC_SETUP_PM2(){
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: Process Manager (PM2)... ${NC}"
    echo -e

    echo -e "${GREEN}## ${YELLOW}Step 1. Install node... ${NC}"
    echo -e

    # Function to compare version numbers
    ver() {
        printf "%03d%03d%03d" $(echo "$1" | tr '.' ' ')
    }

    if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node -v | sed 's/v//')
        if [ $(ver "$NODE_VERSION") -ge $(ver "18.0.0") ]; then
            echo "Node.js is already installed and is v18 or higher, skipping node install..."
        else
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
            node -v
            npm -v
        fi
    else
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        node -v
        npm -v
    fi

    echo -e "${GREEN}## ${YELLOW}Step 2. Install pm2 and script dependencies... ${NC}"
    echo -e

    npm install
    sleep 2s
    sudo npm install -g pm2

    echo -e "${GREEN}## ${YELLOW}Step 3. Start and configure auto-start of monitoring script... ${NC}"
    echo -e

    # The evernode monitor requires sudo access to run
    pm2 start $MONITOR_DIR/index.js --name evernode-monitor
    sleep 2s
    pm2 list
    sleep 2s
    sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $ORIG_USER --hp $ORIG_HOME
    pm2 save
}


FUNC_LOGROTATE(){
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: Logrotate process... ${NC}"
    echo -e

    TMP_FILE05=$(mktemp)
    cat <<EOF > $TMP_FILE05
$ORIG_HOME/.pm2/logs/*.log
    {
        su $ORIG_USER $ORIG_USER
        rotate 10
        copytruncate
        weekly
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
            invoke-rc.d rsyslog rotate >/dev/null 2>&1 || true
        endscript
    }
EOF
    sudo sh -c "cat $TMP_FILE05 > /etc/logrotate.d/evernode-monitor-logs"
    echo -e "OK"
}
    

FUNC_NOPASSWD_SUDO(){
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}## ${YELLOW}Setup: Give current user the ability to sudo /usr/bin/systemctl${NC}"
    echo -e "${GREEN}## ${YELLOW}without needing to provide the sudo password${NC}"
    echo -e

    SUDOERS_LINE="$ORIG_USER ALL=(ALL:ALL) NOPASSWD:/usr/bin/systemctl"
    TMP_FILE06=$(mktemp)
    sudo cp /etc/sudoers $TMP_FILE06

    # Check if the line already exists to prevent duplicate entries
    if ! sudo grep -Fxq "$SUDOERS_LINE" $TMP_FILE06; then
    # Add the new line to the end of the temporary sudoers file
        sudo sed -i "\$a $SUDOERS_LINE" $TMP_FILE06
    
        if sudo visudo -c -f $TMP_FILE06; then
            sudo cp $TMP_FILE06 /etc/sudoers
            echo -e "$ORIG_USER added to sudoers."
        else
            echo -e "Error: visudo check failed. Changes not applied."
        fi
    else
        echo -e "The line already exists in the sudoers file."
    fi
}


FUNC_MONITOR_DEPLOY(){
    
    echo -e "${GREEN}###############################################################################${NC}"
    echo -e "${YELLOW}###############################################################################${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}           ** ${NC}Evernode UptimeRobot Monitor Service Setup${GREEN} **${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${YELLOW}###############################################################################${NC}"
    echo -e "${GREEN}###############################################################################${NC}"
    echo -e
    sleep 2s

    FUNC_VERIFY
    FUNC_PKG_CHECK
    FUNC_INSTALL_SERVICE
    FUNC_FIREWALL_CONFIG
    FUNC_CREATE_ENV
    FUNC_SETUP_PM2
    FUNC_LOGROTATE
    FUNC_NOPASSWD_SUDO
    FUNC_EXIT
}


# setup a clean exit
trap SIGINT_EXIT SIGINT
SIGINT_EXIT(){
    stty sane
    echo
    echo "Exiting before completing the script."
    exit 1
    }


FUNC_EXIT(){
    # remove the sudo timeout for USER_ID.
    echo -e
    echo -e "${GREEN}Performing clean-up:${NC}"
    sudo sh -c "rm -fv /etc/sudoers.d/$TMP_FILENAME01"
    bash ~/.profile
    sudo -u $USER_ID sh -c 'bash ~/.profile'
    echo -e
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
    echo -e "${GREEN}       **${NC} Evernode UptimeRobot Monitor installed ${GREEN}**${NC}"
    echo -e
    echo -e                     "pm2 status : check status and find id"
    echo -e                     "pm2 log <id> : standard install this is id 0 - tail log"
    echo -e                    
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e "${GREEN}#########################################################################${NC}"
    echo -e
	exit 0
	}


FUNC_EXIT_ERROR(){
	exit 1
	}


FUNC_MONITOR_DEPLOY