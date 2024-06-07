#!/bin/bash

# Set Colour Vars
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the absolute path of the script directory
MONITOR_DIR=$HOME/evernode-uptimerobot-monitor
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source $SCRIPT_DIR/evernode_monitor.vars

echo -e "${RED}#########################################################################"
echo -e "${RED}#########################################################################"
echo -e "${RED}"
echo -e "${RED}!!  WARNING  !!${NC} Evernode UptimeRobot Monitor Uninstall ${RED}!!  WARNING  !!${NC}"
echo -e "${RED}"
echo -e "${RED}       This script will remove the Evernode UptimeRobot Monitor.${NC}"
echo -e "${RED}"
echo -e "${GREEN}**  NOTE  **${NC} Your Evernode installation ${GREEN}will not${NC} be touched ${GREEN}**  NOTE  **${NC}"  
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

# Extend the sudo timeout a bit as a way to prompt for the the sudo password early
TMP_FILE01=$(mktemp)
TMP_FILENAME01=$(basename $TMP_FILE01)
echo "Defaults:$USER_ID timestamp_timeout=10" > $TMP_FILE01
sudo sh -c "cat $TMP_FILE01 > /etc/sudoers.d/$TMP_FILENAME01"

# Disable and remove the files used by the uptimeRobot.service
if [ -z "$SCRIPT_DIR" ]; then
  echo -e "SCRIPT_DIR is not defined for some reason. Exiting before something bad happens."
  exit 1
else
  if sudo systemctl list-unit-files --type=service | grep -q "^uptimeRobot.service"; then
    sudo systemctl stop uptimeRobot.service && sudo systemctl disable uptimeRobot.service 
  else
    echo -e "uptimeRobot.service already stopped and/or disabled."
  fi
  if [ -e "$SCRIPT_DIR/uptimeRobot.service" ]; then
    sudo rm -rfv $SCRIPT_DIR/uptimeRobot.service
  else
    echo -e "uptimeRobot.service already removed."
  fi
  if [ -e "$SCRIPT_DIR/uptimeRobotService.py" ]; then
    rm -rfv $SCRIPT_DIR/uptimeRobotService.py
  else
    echo -e "uptimeRobotService.py already removed."
  fi
fi
sudo systemctl daemon-reload

# Remove custom Uptime Robot port in firewall configuration
if sudo systemctl list-unit-files --type=service | grep -q 'ufw.service'; then
    if sudo systemctl is-active --quiet ufw.service; then
        sudo ufw delete allow $CUSTOM_UR_PORT/tcp
        sudo ufw status verbose
    else
        echo -e "UFW is installed but not running. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW removal..."
    fi
else
    echo -e "UFW is not installed. This is ${RED}NOT GOOD${NC} unless you have other protection in place. Skipping UFW removal..."
fi

# Remove the .env
if [ -e "$MONITOR_DIR/.env" ]; then
  rm -rfv $MONITOR_DIR/.env
fi

# Remove pm2, pm2 config/log files, and startup process
echo -e "Removing pm2 and startup process..."
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 unstartup systemd -u $LOGNAME --hp $HOME
sudo npm remove -g pm2
sudo rm -rfv $HOME/.pm2

# Remove logrotate files
sudo rm -rfv /etc/logrotate.d/evernode-monitor-logs

# Remove user from sudoers
TMP_FILE07=$(mktemp)
SUDOERS_LINE="$LOGNAME ALL=(ALL:ALL) NOPASSWD:/usr/bin/systemctl"
sudo cp /etc/sudoers $TMP_FILE07
sudo sed -i "\|$SUDOERS_LINE|d" $TMP_FILE07
if sudo visudo -c -f $TMP_FILE07; then
  sudo cp $TMP_FILE07 /etc/sudoers
  echo -e "User removed from sudoers."
else
  echo -e "Error: visudo check failed. Changes not applied."
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