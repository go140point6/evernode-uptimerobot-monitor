require('dotenv').config();
require('log-timestamp');
const cron = require('node-cron');
const { checkSudo } = require('./utils/checkSudo');
//const { checkStatus } = require('./main/checkStatus');
const { checkGas } = require('./main/checkGas.js');
const { toggleAlert } = require('./main/toggleAlert');
const { checkStatus } = require('./main/checkLedgerStatus');
const { getAddress } = require('./main/getAddress');

// sudo -u sashireputationd XDG_RUNTIME_DIR=/run/user/1030 systemctl --user is-active sashimono-reputationd
// sudo -u sashimbxrpl XDG_RUNTIME_DIR=/run/user/1029 systemctl --user is-active sashimono-mb-xrpl
// No need to run as sudo any more?

(async () => {
    try {
        //const sudoOk = await checkSudo()
        //console.log(sudoOk)
        if (process.env.LEASE_CRIT > 1) {
            console.log("Check .env, the LEASE_CRIT ratio must be 1 or less. Aborting.")
            process.exit(1); // Exit the current process
        }
        const address = await getAddress()
        console.log("Host address to monitor is: ", address)

        const monitorNode = cron.schedule(process.env.CRON_SCHED, async () => {
            console.log("")
            const gas = await checkGas(address)
            //console.log("Gas crtical:", gas) // boolean
            const data = await checkStatus(address)
            //console.log(data)

            if (data.lastHeartbeatOk && data.leaseAmountOk && !gas) { // if lastHeartbeatOk (true) AND leaseAmountOk (true) AND gas is not crtical (false)
                const res = await toggleAlert(true) // tell toggleAlert we should be green :)
            } else { // if gas is critical (true) OR either of the other two are not OK (false)
                console.log("Alert generated or continued, see below for reason:")
                if (data.lastHeartbeatOk) {
                    console.log("Heartbeat is OK.")
                } else {
                    console.log("No heartbeat transaction found since the previous moment began.")
                }
                if (data.leaseAmountOk) {
                    console.log("Current lease amount is OK.")
                } else {
                    console.log("Your LEASE_CRIT value was hit, meaning it's time to lower your instance lease values.")
                }
                if (!gas) {
                    console.log("XAH level is OK.")
                } else {
                    console.log("Your GAS_CRIT value was hit, meaning it's time to top up.")
                }
                const res = await toggleAlert(false) // tell toggleAlert we should be red :(
            }
        })
    } catch(error) {
        console.error("Some error: ", error)
    }
})();