require('dotenv').config();
require('log-timestamp');
const cron = require('node-cron');
//const { checkSudo } = require('./utils/checkSudo');
const { checkGas } = require('./main/checkGas.js');
const { toggleAlert } = require('./main/toggleAlert');
const { checkStatus } = require('./main/checkStatus');
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

            if (data.activeOk && data.leaseAmountOk && data.maxInstancesOk && data.hostReputationOk && !gas) {
                const res = await toggleAlert(true) // tell toggleAlert we should be green :)
            } else {
                const res = await toggleAlert(false) // tell toggleAlert we should be red :(
            }
        })
    } catch(error) {
        console.error("Some error: ", error)
    }
})();