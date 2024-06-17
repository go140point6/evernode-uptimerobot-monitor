const fs = require('fs').promises;
const evernode = require("evernode-js-client");

async function checkStatusSingle(address) {
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

        // default required values from hook
        const hostMinInstanceCount = heartbeatClient.config.rewardConfiguration.hostMinInstanceCount // number
        const hostMaxLeaseAmtString = heartbeatClient.config.rewardInfo.hostMaxLeaseAmount // string
        const hostMaxLeaseAmount = parseFloat(hostMaxLeaseAmtString) // number
        const hostReputationThreshold = heartbeatClient.config.rewardConfiguration.hostReputationThreshold // number

        const res = await heartbeatClient.getHostInfo(address)

        const version = res.version // string
        const hostReputation = res.hostReputation // number
        const maxInstances = res.maxInstances // number
        const leaseAmountString = res.leaseAmount // string
        const leaseAmount = parseFloat(leaseAmountString) // number
        const active = res.active // boolean

        let currentLeaseRatio = (leaseAmount / hostMaxLeaseAmount) // number

        await heartbeatClient.disconnect()
        await xrplApi.disconnect()
        return{ hostMinInstanceCount, hostMaxLeaseAmount, hostReputationThreshold, version, hostReputation, maxInstances, leaseAmount, active }

    } catch (err) {
        console.error('Error in checkCurrentValues:', err)
    }
}

async function checkStatus(sharedArrays) {
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

        // default required values from hook
        const hostMinInstanceCount = heartbeatClient.config.rewardConfiguration.hostMinInstanceCount // number
        sharedArrays.support.hookRequiredValues[0].hostMinInstanceCount = hostMinInstanceCount
        const hostMaxLeaseAmtString = heartbeatClient.config.rewardInfo.hostMaxLeaseAmount // string
        const hostMaxLeaseAmount = parseFloat(hostMaxLeaseAmtString) // number
        sharedArrays.support.hookRequiredValues[0].hostMaxLeaseAmount = hostMaxLeaseAmount
        const hostReputationThreshold = heartbeatClient.config.rewardConfiguration.hostReputationThreshold // number
        sharedArrays.support.hookRequiredValues[0].hostReputationThreshold = hostReputationThreshold

        for (let i = 0; i < sharedArrays.support.myNodes.length; i++) {
            const address = sharedArrays.support.myNodes[i].address
            
            const res = await heartbeatClient.getHostInfo(address)

            const lastHeartbeatIndex = res.lastHeartbeatIndex // number
            sharedArrays.support.currentValues[i].lastHeartbeatIndex = lastHeartbeatIndex
            const version = res.version // string
            sharedArrays.support.currentValues[i].version = version
            const hostReputation = res.hostReputation // number
            sharedArrays.support.currentValues[i].hostReputation = hostReputation
            const maxInstances = res.maxInstances // number
            sharedArrays.support.currentValues[i].maxInstances = maxInstances
            const leaseAmountString = res.leaseAmount // string
            const leaseAmount = parseFloat(leaseAmountString) // number
            sharedArrays.support.currentValues[i].leaseAmount = leaseAmount
            const active = res.active // boolean
            sharedArrays.support.currentValues[i].active = active

            let currentLeaseRatio = (leaseAmount / hostMaxLeaseAmount) // number
            let critLeaseRatioString = process.env.LEASE_CRIT // string
            let critLeaseRatio = parseFloat(critLeaseRatioString) // number

            // Host active or inactive?
            if (active) {
                sharedArrays.support.myNodes[i].activeOk = true
            }

            // Instance lease amount to much?
            if (leaseAmount < hostMaxLeaseAmount) {
                sharedArrays.support.myNodes[i].leaseAmountOk = true
                if (currentLeaseRatio < critLeaseRatio) {
                    sharedArrays.support.myNodes[i].leaseAmountRatioOk = true
                }
            }

            // Instance count less than required?
            if (maxInstances >= hostMinInstanceCount) {
                sharedArrays.support.myNodes[i].maxInstancesOk = true
            }

            // Reputation less than required?
            if (hostReputation >= hostReputationThreshold) {
                sharedArrays.support.myNodes[i].hostReputationOk = true
            }
        }

        await heartbeatClient.disconnect()
        await xrplApi.disconnect()
        return

    } catch (err) {
        console.error('Error in checkCurrentValues:', err)
    }
}

module.exports = {
    checkStatus,
    checkStatusSingle
}