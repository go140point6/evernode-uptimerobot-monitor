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

# Get current user id and store as var
USER_ID=$(getent passwd $EUID | cut -d: -f1)

# Authenticate sudo perms before script execution to avoid timeouts or errors.
# Extend sudo timeout to 20 minutes, instead of default 5 minutes.
if sudo -l > /dev/null 2>&1; then
    TMP_FILE01=$(mktemp)
    TMP_FILENAME01=$(basename $TMP_FILE01)
    echo "Defaults:$USER_ID timestamp_timeout=20" > $TMP_FILE01
    sudo sh -c "cat $TMP_FILE01 > /etc/sudoers.d/$TMP_FILENAME01"
    HOME_DIR=$HOME
else
    echo "The user $USER_ID doesn't appear to have sudo privledges, add to sudoers or run as root."
    FUNC_EXIT_ERROR;
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
    echo -e "${GREEN}## ${YELLOW}Install uptimeRobot.service... ${NC}"
    echo -e

    echo -e "${GREEN}## ${YELLOW}Step 1. Create service... ${NC}"
    echo -e

    TMP_FILE02=$(mktemp)
    URSERVICE_PY_TEMPLATE=$SCRIPT_DIR/uptimeRobotService.py.template

    # Read the template file, replace the placeholder with the actual port, and write to the temp file
    sudo sed "s|{{PORT}}|$CUSTOM_UR_PORT|" $URSERVICE_PY_TEMPLATE > $TMP_FILE02

    # Move the temp file to the desired location
    sh -c "cat $TMP_FILE02 > $SCRIPT_DIR/uptimeRobotService.py"
    chmod 755 $SCRIPT_DIR/uptimeRobotService.py
    echo -e "OK"
    sleep 2s

    echo -e "${GREEN}## ${YELLOW}Step 2. Create service unit file... ${NC}"
    echo -e

    TMP_FILE03=$(mktemp)
    URSERVICE_UNIT_TEMPLATE=$SCRIPT_DIR/uptimeRobotService.unit.template

    # Read the template file, replace the placeholder with the script dir, and write to the temp file
    sudo sed "s|{{DIR}}|$SCRIPT_DIR|" $URSERVICE_UNIT_TEMPLATE > $TMP_FILE03

    # Move the temp file to the desired location
    sh -c "cat $TMP_FILE03 > $SCRIPT_DIR/uptimeRobot.service"
    sudo ln -sfn $SCRIPT_DIR/uptimeRobot.service /etc/systemd/system/uptimeRobot.service
    echo -e "OK"
    sleep 3s

    echo -e "${GREEN}## ${YELLOW}Step 3. Enable and start service... ${NC}"
    echo -e

    sudo systemctl enable uptimeRobot.service
    sudo systemctl start uptimeRobot.service
    sudo systemctl daemon-reload
    sudo systemctl status uptimeRobot.service
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
            echo -e "${GREEN}## ${YELLOW}Step 2. Add monitoring port $CUSTOM_UR_PORT... ${NC}"
            echo -e
            sudo ufw allow $CUSTOM_UR_PORT/tcp
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

    echo -e "${GREEN}## ${YELLOW}Step 1. Install PM2 globally using NPM... ${NC}"
    echo -e

    sudo npm install -g npm
    sudo npm install -g pm2

    echo -e "${GREEN}## ${YELLOW}Step 2. Start and configure auto-start of monitoring script... ${NC}"
    echo -e

    # This configures the regular user if not using root
    # pm2 list
    # sleep 2s

    # The evernode monitor requires sudo access to run
    pm2 start $MONITOR_DIR/index.js --name evernode-monitor
    sleep 2s
    pm2 list
    sleep 2s
    env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $LOGNAME --hp $HOME_DIR
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
$HOME/.pm2/logs/*.log
    {
        su $USER_ID $USER_ID
        rotate 10
        copytruncate
        daily
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
    

FUNC_MONITOR_DEPLOY(){
    
    echo -e "${GREEN}###############################################################################${NC}"
    echo -e "${YELLOW}###############################################################################${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${GREEN}                 **${NC}Evernode UptimeRobot Monitor Service${GREEN}**${NC}"
    echo -e "${GREEN}${NC}"
    echo -e "${RED}!!  ACHTUNG  !!${NC} This MUST be installed on your Evernode host ${RED}!!  ATTENTION  !!${NC}"
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