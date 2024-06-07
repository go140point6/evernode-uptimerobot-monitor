//const fs = require('fs').promises;
const xrpl = require("xrpl");

async function checkGas(address) {
    try {

        const client = new xrpl.Client(process.env.WS_MAINNET);
        await client.connect()

        const balance = await client.request({
            command: "account_info",
            account: address
        })

        const xahBalanceDrops = balance.result.account_data.Balance
        const xahBalanceXah = xrpl.dropsToXrp(xahBalanceDrops) // number

        //console.log("XAH balance, in drops: ", xahBalanceDrops)
        //console.log("XAH balance, in XAH: ", xahBalanceXah)
        //console.log("XAH in drops typeof ", typeof(xahBalanceDrops))
        //console.log("XAH in XAH typeof ", typeof(xahBalanceXah))

        await client.disconnect()
        
        if (xahBalanceXah < process.env.GAS_CRIT) {
            console.log("[WARN] Gas is critical, add XAH to ", address)
            return(true)
        } else {
            console.log("[OK] XAH balance is above critical threshold.")
            return(false)
        }

    } catch (err) {
        console.error('Error in checkGas:', err)
    }
}

module.exports = {
    checkGas
}