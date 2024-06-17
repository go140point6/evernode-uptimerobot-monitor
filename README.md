# evernode-uptimerobot-monitor
### Monitor Evernode status with Uptime Robot

#### Second version - monitor ports from centralized server
- Monitor all of your evernode hosts from a single centralized server.
- Creates a dummy service listening on user-defined port for each evernode monitored.
- Configure Uptime Robot (only supported alert mechanism in this version) to monitor that port.
- Designed for single alert, anything goes wrong with monitored evernode and alert will trigger. Review log for specifics.

#### Features
- Fully (almost) automatic install and uninstallation via bash shell script.
- Checks XAH level based on user-defined setting, triggers alert on low gas.
- Queries the Heartbeat hook checking if host active. If inactive, trigger alert.
- Check current configured leaseAmount and compares to current maxLease amount from ledger based on user-defined ratio, if ratio > 1 trigger alert.
- Alerts are via Uptime Robot service port monitoring, free for up to 50 monitors, with email and mobile device alerts available.
- Uses PM2 process manager for logging and ensuring automatic startup on system reboot or app crash.

#### Issues/To do list
- Public infrastructure (xahau.network) throws errors at times due to rate of queries.
- Exploring ways to build the myNodes.csv and currentValues.csv automatically, for now you must create manually.
- 

#### To check a single address
Note: This should be done on one of your evernode hosts since it already has the proper version of Node.js installed. Only clone to one, and then check any number of addresses.
- Clone the repo and install dependencies:
```sh
git clone https://github.com/go140point6/evernode-uptimerobot-monitor.git
cd evernode-uptimerobot-monitor
npm install
```
- Run the standalone script in utils and provide the address when prompted:
```js
node ./utils/standalone-evernode-check.js
```
- OPTIONAL: delete the repo when done if you wish.

#### To Install Full Monitoring
- Clone the repo and install dependencies
```sh
git clone https://github.com/go140point6/evernode-uptimerobot-monitor.git
cd evernode-uptimerobot-monitor
```
- Important! Currently you MUST create the myNodes.csv and currentValues.csv before running the setup script. Look at the template, create a copy named correctly and edit to match YOUR evernodes. Specifically use your addresses, host and nick in myNodes and match nick in currentValues. All other info can remain default (change ports if you want but not required). Do not change any other info (leave all as false).
- Once .csv files are in place, run the setup script (will prompt for sudo)
```sh
./utils/setupUptimeRobotService.sh
```
Note: the setup script will create/download all the other files needed, open the firewall, and start the monitoring. Only thing left for installation is to create your port monitors on UptimeRobot matching the ports you want to monitor.

#### Check logs
- There are two sets of logs:
```sh
cat ./logs/evernode-uptimerobot-monitor.log
```
and
```sh
cat ~/.pm2/logs/evernode-monitor.log
cat ~/.pm2/logs/evernode-monitor.error
```
Review for specifics if an alert raised. You can also see the logs in real-time:
```sh
pm2 log 0
```

