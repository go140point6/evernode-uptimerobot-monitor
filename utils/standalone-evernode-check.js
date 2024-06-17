const readline = require('readline-sync');
const Logger = require("@ptkdev/logger");
const { checkGasSingle } = require('../main/checkGas');
const { checkStatusSingle } = require('../main/checkStatus');
const { alertMessagesSingle } = require('../main/toggleAlert');

const logOptions = {
	language: "en", // en / it / pl / es / pt / de / ru / fr
	colors: true,
	debug: true,
	info: true,
	warning: true,
	error: true,
	sponsor: false,
	write: false,
}

// Function to validate XRPL address
function isValidXRPLAddress(address) {
    const regex = /^r[1-9A-HJ-NP-Za-km-z]{24,34}$/
    return regex.test(address)
}

(async () => {
    //const address = readline.question('Please enter your XRPL address: ')
    const address = 'rUHtnEdBNqsxRC4zvLvc5FB5MxQC18SU5D'
    const logger = new Logger(logOptions)

    if (isValidXRPLAddress(address)) {
        logger.info(`The XAHL address is valid, checking: ${address}`)
        const gas = await checkGasSingle(address)
        //console.log(gas)
        const { hostMinInstanceCount, hostMaxLeaseAmount, hostReputationThreshold, version, hostReputation, maxInstances, leaseAmount, active } = await checkStatusSingle(address)
        //console.log(hostMinInstanceCount, hostMaxLeaseAmount, hostReputationThreshold, version, hostReputation, maxInstances, leaseAmount, active)
        await alertMessagesSingle(logger, gas, active, leaseAmount, hostMaxLeaseAmount, maxInstances, hostMinInstanceCount, hostReputation, hostReputationThreshold, version)
    } else {
        console.log('The XRPL address is invalid. Please enter a valid address.')
        process.exit(1)
    }
})()