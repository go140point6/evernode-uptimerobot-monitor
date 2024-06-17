const readline = require('readline-sync');
const Logger = require("@ptkdev/logger");
const { checkGasSingle } = require('../main/checkGas');
const { checkStatusSingle } = require('../main/checkStatus');
const { toggleAlertSingle } = require('../main/toggleAlert');


// Function to validate XRPL address
function isValidXRPLAddress(address) {
    const regex = /^r[1-9A-HJ-NP-Za-km-z]{24,34}$/
    return regex.test(address)
}

(async () => {
    const address = readline.question('Please enter your XRPL address: ')

    if (isValidXRPLAddress(address)) {
        console.log('The XRPL address is valid:', address)
        const gas = await checkGasSingle(address)
        //console.log(gas)
        const { hostMinInstanceCount, hostMaxLeaseAmount, hostReputationThreshold, version, hostReputation, maxInstances, leaseAmount, active } = await checkStatusSingle(address)
        //console.log(hostMinInstanceCount, hostMaxLeaseAmount, hostReputationThreshold, version, hostReputation, maxInstances, leaseAmount, active)
        await toggleAlertSingle 
    } else {
        console.log('The XRPL address is invalid. Please enter a valid address.')
        process.exit(1)
    }
})()