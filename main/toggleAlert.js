const util = require('util');
const exec = util.promisify(require('child_process').exec);

const isServiceRunning = async () => {
  return new Promise((resolve) => {
    exec("sudo systemctl is-active uptimeRobot.service", (error) => {
      if (error) { // exec treats anything other than "active" as an error, and 3 is "inactive" which is what we want
        if (error.code === 3) {
          resolve(false)  // Service is inactive
        } else {
          console.error(`Error checking service status: ${error.message}`)
          resolve("error")  // Other errors
        }
      } else {
        resolve(true)  // Service is active
      }
    })
  })
}

const startService = async () => {
  const status = await isServiceRunning()
  console.log("Heartbeat detected, current lease and gas levels OK, ensure uptimeRobot.service is started...")
  if (status === true) {
    console.log("Service is already started.")
    return
  } else if (status === false) {
    try {
      const { stderr } = await exec("sudo systemctl start uptimeRobot.service")
      if (stderr) {
        console.error(`Error starting service: ${stderr}`)
      } else {
        console.log("Service started.")
        //const results = await exec("sudo systemctl status uptimeRobot.service")
        //console.log("Results: ", results.stdout) 
      }
    } catch (error) {
      console.error(`Error starting service: ${error.message}`)
    }
  }
}

const stopService = async () => {
  const status = await isServiceRunning()
  console.log("Alert triggered for one or more reasons noted above, ensure uptimeRobot.service is stopped...")
  if (status === false) {
    console.log("Service is already stopped.")
    return
  } else if (status === true) {
    try {
      const { stderr } = await exec("sudo systemctl stop uptimeRobot.service")
      if (stderr) {
        console.error(`Error stopping service: ${stderr}`)
      } else {
        console.log("Service stopped.")
        //const results = await exec("sudo systemctl status uptimeRobot.service")
        //console.log("Results: ", results.stdout) 
      }
    } catch (error) {
      console.error(`Error stopping service: ${error.message}`)
    }
  }
}

async function toggleAlert(state) {
  if (state) { // State "active" so enable port if not already enabled
    await startService()
  } else { // State "Not active" so disable port if not already disabled
    await stopService()
  }
}

  module.exports = {
    toggleAlert
}
  