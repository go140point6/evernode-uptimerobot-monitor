const fs = require('fs').promises;
const evernode = require("evernode-js-client");

data = {
    activeOk: false,
    leaseAmountOk: false,
    maxInstancesOk: false,
    hostReputationOk: false
}

async function checkCurrentValues(address) {
    try {
        await evernode.Defaults.useNetwork('mainnet')
        const xrplApi = new evernode.XrplApi(null, { autoReconnect: true })
        evernode.Defaults.set({
            xrplApi: xrplApi
        })

        await xrplApi.connect()

        //console.log(xrplApi)

        const heartbeatClient = await evernode.HookClientFactory.create(evernode.HookTypes.heartbeat)
        await heartbeatClient.connect()

        //console.log(heartbeatClient)

        const hostMinInstanceCount = heartbeatClient.config.rewardConfiguration.hostMinInstanceCount // number
        const hostMaxLeaseAmtString = heartbeatClient.config.rewardInfo.hostMaxLeaseAmount // string
        const hostMaxLeaseAmt = parseFloat(hostMaxLeaseAmtString) // number
        const hostReputationThreshold = heartbeatClient.config.rewardConfiguration.hostReputationThreshold // number

        const res = await heartbeatClient.getHostInfo(address)

        //console.log(res)

        const lastHeartbeatIndex = res.lastHeartbeatIndex // number
        const version = res.version // string
        const hostReputation = res.hostReputation // number
        const maxInstances = res.maxInstances // numnber
        const leaseAmountString = res.leaseAmount // string
        const leaseAmount = parseFloat(leaseAmountString) // number
        const active = res.active // boolean

        await heartbeatClient.disconnect()
        await xrplApi.disconnect()

        let currentLeaseRatio = (leaseAmount / hostMaxLeaseAmt) // number
        let critLeaseRatioString = process.env.LEASE_CRIT // string
        let critLeaseRatio = parseFloat(critLeaseRatioString) // number

        // Host active or inactive?
        if (active) {
            console.log("[OK] Heartbeat hook reports host is active.")
            data.activeOk = true
        } else {
            console.log("[ERROR] Heartbeat hook reports host is inactive. No rewards for you.")
        }

        // Instance lease ammount to much?
        if (leaseAmount < hostMaxLeaseAmt) {
            console.log(`[OK] leaseAmount of ${leaseAmount} is less than current hostMaxLeaseAmt of ${hostMaxLeaseAmt.toFixed(6)} with a ratio of ${currentLeaseRatio.toFixed(2)}. Now checking critLeaseRatio trigger...`)
            if (currentLeaseRatio < critLeaseRatio) {
                console.log(`[OK] currentLeaseRatio of ${currentLeaseRatio.toFixed(2)} is less than critLeaseRatio of ${critLeaseRatio}. This is GOOD.`)
                data.leaseAmountOk = true
            } else {
                console.log(`[WARNING] currentLeaseRatio of ${currentLeaseRatio.toFixed(2)} is greater than critLeaseRatio of ${critLeaseRatio}. Suggest you lower your leaseAmount per instance to ensure continued rewards.`)
            }
        } else {
            console.log(`[ERROR] leaseAmount of ${leaseAmount} is greater than current hostMaxLeaseAmt of ${hostMaxLeaseAmt.toFixed(6)} with a ratio of ${currentLeaseRatio.toFixed(2)}. No rewards for you.`)
        }

        // Instance count less than required?
        if (maxInstances >= hostMinInstanceCount) {
            console.log(`[OK] Current instances of ${maxInstances} is greater than or equal to the current hostMinInstanceCount of ${hostMinInstanceCount}.`)
            data.maxInstancesOk = true
        } else {
            console.log(`[ERROR] Current instances of ${maxInstances} is less than the current hostMinInstanceCount of ${hostMinInstanceCount}. No rewards for you.`)
        }

        // Reputation less than required?
        if (hostReputation >= hostReputationThreshold) {
            console.log(`[OK] Current hostReputation of ${hostReputation} is greater than or equal to the current hostReputationThreshold of ${hostReputationThreshold}.`)
            data.hostReputationOk = true
        } else {
            console.log(`[ERROR] Current hostReputation of ${hostReputation} is less than the current hostReputationThreshold of ${hostReputationThreshold}. No rewards for you.`)
        }
        
    } catch (err) {
        console.error('Error in checkCurrentValues:', err)
    }
}

async function checkStatus(address) {
    //console.log(address)
    await checkCurrentValues(address)
    return(data)
}

module.exports = {
    checkStatus
}