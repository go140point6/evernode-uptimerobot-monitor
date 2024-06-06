# evernode-uptimerobot-monitor
### Monitor Evernode status with Uptime Robot

#### First version
- Must be installed on the Evernode host.
- Creates a dummy service listening on user-defined port.
- Configure Uptime Robot (only support alert mechanism in this version) to monitor that port.
- Designed for single alert, anything goes wrong and alert will trigger. Review log for specifics.

#### Features
- Fully automatic install and uninstallation via bash shell script.
- Automatically gets host address from Evernode config file.
- Checks XAH level based on user-defined setting, triggers alert on low gas.
- Looks for heartbeat tx on the ledger only as far back as needed (currentMoment -1), if not found, trigger alert on missing heartbeat.
- Check current configured leaseAmount and compares to current maxLease amount from ledger based on user-defined ratio, if ratio > 1 trigger alert.
- Alerts are via Uptime Robot service port monitoring, free for up to 50 monitors, with email and mobile device alerts available.
- Uses PM2 process manager for logging and ensuring automatic startup on system reboot or app crash.

#### To Install
- Clone the repo and install dependencies
```sh
git clone https://github.com/go140point6/evernode-uptimerobot-monitor.git
cd evernode-uptimerobot-monitor
npm install
```
- Run the setup script (requires sudo)
```sh
./utils/setupUptimeRobotService.sh

