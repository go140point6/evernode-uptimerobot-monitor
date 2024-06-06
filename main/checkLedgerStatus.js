const fs = require('fs').promises;
const xrpl = require("xrpl");
const evernode = require("evernode-js-client");

data = {
    lastHeartbeatOk: false,
    leaseAmountOk: false
}

async function getLeaseAmt() {
    try {
        const data = await fs.readFile(process.env.ACCT_DETAILS, 'utf8')
        const jsonData = JSON.parse(data)
        //console.log("Current configured lease ammount: ", jsonData.xrpl.leaseAmount) // number
        return jsonData.xrpl.leaseAmount
    } catch (err) {
        console.error('Error:', err)
        throw err
    }
}

async function checkCurrentValues() {
    try {
        await evernode.Defaults.useNetwork('mainnet')
        const xrplApi = new evernode.XrplApi(null, { autoReconnect: true })
        evernode.Defaults.set({
            xrplApi: xrplApi
        })

        await xrplApi.connect()

        // console.log(xrplApi)

        const heartbeatClient = await evernode.HookClientFactory.create(evernode.HookTypes.heartbeat)
        await heartbeatClient.connect()

        const heartbeatHook = heartbeatClient.config.heartbeatAddress

        //console.log("hbClient savedMoment: ", heartbeatClient.config.rewardInfo.savedMoment)
        //console.log("hbClient hostMaxLeaseAmount: ", heartbeatClient.config.rewardInfo.hostMaxLeaseAmount)
        let currentMoment = heartbeatClient.config.rewardInfo.savedMoment // number
        let momentBaseIndex = heartbeatClient.config.momentBaseInfo.baseIdx // number
        let configuredLeaseAmt = await getLeaseAmt() // number
        let maxLeaseAmtString = (heartbeatClient.config.rewardInfo.hostMaxLeaseAmount) // string
        let maxLeaseAmt = parseFloat(maxLeaseAmtString) // number

        await heartbeatClient.disconnect()
        await xrplApi.disconnect()
        return [currentMoment, momentBaseIndex, configuredLeaseAmt, maxLeaseAmt, heartbeatHook]

    }catch (error) {
        console.error("Some error ", error)
    }
}

async function checkLastHeartbeat(address) {
    try {

        const [currentMoment, momentBaseIndex, configuredLeaseAmt, maxLeaseAmt, heartbeatHook] = await checkCurrentValues(address)

        //console.log(currentMoment)
        //console.log(momentBaseIndex)
        //console.log(configuredLeaseAmt)
        //console.log(maxLeaseAmt)

        const client = new xrpl.Client(process.env.WS_MAINNET)
        await client.connect()

        let currentMomentStart = (momentBaseIndex + ((currentMoment - 1) * 3600)) - 946684800 // number
        //console.log("currentMomentStart in Ripple Epoch: ", currentMomentStart)

        let lastHeartbeat
        let heartbeatHookTxFound = false

        let ledgerIndex= -1
        let marker = ''
        //let limit = 10
        while (typeof marker === 'string') {
            const response = await client.request({
                command: "account_tx",
                account: address,
                "ledger_index_min": -1,
                "ledger_index_max": ledgerIndex,
                "binary": false,
                //"limit": limit,
                "forward": false, 
                marker: marker === '' ? undefined : marker
            })
            marker = response?.marker === marker ? null : response?.marker

            //console.log(response.result.transactions)

            for (let tIndex = 0; tIndex < response.result.transactions.length; tIndex++) {
                let transaction = response.result.transactions[tIndex]

                if (transaction.tx.date < currentMomentStart) {
                    marker = null;
                }

                if (transaction.tx.Destination == heartbeatHook) {
                    //console.log("Last heartbeat tx: ", transaction.tx.date)
                    lastHeartbeat = transaction.tx.date // number
                    heartbeatHookTxFound = true
                    break
                }
            }

            if (marker === null) {
                break
            }

            // if (!heartbeatHookTxFound) {
            //     console.log(`No tx to the heartbeatHook found in last ${limit} transactions.`)
            //     return(data)
            // }
        }

        let currentLeaseRatio = (configuredLeaseAmt / maxLeaseAmt) // number
        let critLeaseRatioString = process.env.LEASE_CRIT // string
        let critLeaseRatio = parseFloat(critLeaseRatioString) // number

        if (lastHeartbeat >= currentMomentStart) {
            console.log("Heartbeat seen in previous or current moment. This is GOOD.")
            data.lastHeartbeatOk = true
        } else {
            console.log("No heartbeat transaction found since the previous moment began. This is BAD.")
        }

        if (maxLeaseAmt > configuredLeaseAmt) {
            console.log(`currentLeaseAmount of ${configuredLeaseAmt} is less than current maxLeaseAmt of ${maxLeaseAmt.toFixed(6)} with a ratio of ${currentLeaseRatio.toFixed(2)}. This is GOOD.`)
            if (critLeaseRatio > currentLeaseRatio) {
                console.log(`critLeaseRatio of ${critLeaseRatio} is greater than currentLeaseRatio of ${currentLeaseRatio.toFixed(2)}. This is GOOD.`)
                data.leaseAmountOk = true
            } else {
                console.log(`critLeaseRatio of ${critLeaseRatio} is less than currentLeaseRatio of ${currentLeaseRatio.toFixed(2)}. This means trigger the alert.`)
            }
        } else {
            console.log(`currentLeaseAmount of ${configuredLeaseAmt} is greater than current maxLeaseAmt of ${maxLeaseAmt.toFixed(6)} with a ratio of ${currentLeaseRatio.toFixed(2)}. This is BAD.`)    
        }

        await client.disconnect()
    } catch (err) {
        console.error('Error in checkLastHeartbeat:', err)
    }
}

async function checkStatus(address) {
    //console.log(address)
    await checkLastHeartbeat(address)
    return(data)
}

module.exports = {
    checkStatus
}