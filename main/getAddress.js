const fs = require('fs').promises;

async function getAddress() {
    try {
        const data = await fs.readFile(process.env.ACCT_DETAILS, 'utf8')
        const jsonData = JSON.parse(data)
        return jsonData.xrpl.address
    } catch (err) {
        console.error('Error:', err)
        throw err
    }
}

module.exports = {
    getAddress
}