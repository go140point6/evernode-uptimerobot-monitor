//const fs = require('fs').promises;
const xrpl = require("xrpl");

async function checkGasSingle(address) {
    try {

        const client = new xrpl.Client('wss://xahau.network');
        await client.connect()

        const balance = await client.request({
            command: "account_info",
            account: address
        })

        const xahBalanceDrops = balance.result.account_data.Balance
        const xahBalanceXah = xrpl.dropsToXrp(xahBalanceDrops) // number
        let gas = xahBalanceXah.toFixed(2)

        await client.disconnect()
        return(gas)
    } catch (error) {
        console.error('Error in checkGasSingle:', error)
    }
}

async function checkGas(sharedArrays) {
    try {

        const client = new xrpl.Client(process.env.WS_MAINNET);
        await client.connect()

        for (let i = 0; i < sharedArrays.support.myNodes.length; i++) {
            const address = sharedArrays.support.myNodes[i].address
            
            const balance = await client.request({
                command: "account_info",
                account: address
            })

            const xahBalanceDrops = balance.result.account_data.Balance
            const xahBalanceXah = xrpl.dropsToXrp(xahBalanceDrops) // number
            sharedArrays.support.currentValues[i].gas = xahBalanceXah.toFixed(2)
    
            if (xahBalanceXah < process.env.GAS_CRIT) {
                sharedArrays.support.myNodes[i].gas = true
            } 
        }

        await client.disconnect()
        
    } catch (err) {
        console.error('Error in checkGas:', err)
    }
}

module.exports = {
    checkGas,
    checkGasSingle
}