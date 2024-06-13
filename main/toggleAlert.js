const util = require('util');
const { sleep } = require('../shared/sleep');
const exec = util.promisify(require('child_process').exec);

const isServiceRunning = async (serviceName) => {
    return new Promise((resolve) => {
      exec(`sudo systemctl is-active ${serviceName}.service`, (error) => {
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

const startService = async (serviceName, logger) => {
  const status = await isServiceRunning(serviceName)
  logger.info(`${serviceName}: All systems go! Previous alerts, if present, cleared.`)
  if (status === true) {
    return
  } else if (status === false) {
    try {
      const { stderr } = await exec(`sudo systemctl start ${serviceName}.service`)
      if (stderr) {
        console.error(`Error starting service: ${stderr}`)
      }
      return
    } catch (error) {
      console.error(`Error starting service: ${error.message}`)
    }
  }
}

const stopService = async (serviceName, logger) => {
  const status = await isServiceRunning(serviceName)
  logger.info(`${serviceName} has triggered an alert:`)
  if (status === false) {
    return
  } else if (status === true) {
    try {
      const { stderr } = await exec(`sudo systemctl stop ${serviceName}.service`)
      if (stderr) {
        console.error(`Error stopping service: ${stderr}`)
      }
      return
    } catch (error) {
      console.error(`Error stopping service: ${error.message}`)
    }
  }
}

async function toggleAlert(sharedArrays, logger) {
  for (let i = 0; i < sharedArrays.support.myNodes.length; i++) {
    let serviceName = sharedArrays.support.myNodes[i].nick
    if (sharedArrays.support.myNodes[i].activeOk && sharedArrays.support.myNodes[i].leaseAmountOk && sharedArrays.support.myNodes[i].leaseAmountRatioOk && sharedArrays.support.myNodes[i].maxInstancesOk && sharedArrays.support.myNodes[i].hostReputationOk && !sharedArrays.support.myNodes[i].gas) {
      //await startService(serviceName, logger)
      if (i === 0) {
        logger.info('START~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')  
      } else if (i > 0 && i <= sharedArrays.support.myNodes.length - 1 ) {
        logger.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')  
      }
      logger.info('All systems go! Previous alerts, if any, cleared.', serviceName)
      if (i === sharedArrays.support.myNodes.length - 1) {
        logger.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~END')
        logger.info('')
      }
      sleep(2000)
    } else {
      //await stopService(serviceName, logger)
      if (i === 0) {
        logger.info('START~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')  
      } else if (i > 0 && i <= sharedArrays.support.myNodes.length - 1 ) {
        logger.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')  
      }
      logger.error('***Alert triggered***', serviceName)
      sleep(2000)
      await alertMessages(sharedArrays, i, logger)
      if (i === sharedArrays.support.myNodes.length - 1) {
        logger.info('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~END')
        logger.info('')
      }
    }
  }
}

async function alertMessages(sharedArrays, i, logger) {
  try {

    let address = sharedArrays.support.myNodes[i].address

    // Gas below critical threshold?
    let gas = sharedArrays.support.myNodes[i].gas
    if (!gas) {
      logger.info(`XAH balance for account is above critical threshold for ${address}.`)
    } else {
      logger.error(`Gas is critical, add XAH to ${address}.`)
    }

    // Host active or inactive?
    let active = sharedArrays.support.myNodes[i].activeOk
    if (active) {
      logger.info("Heartbeat hook reports host is active.")
    } else {
      logger.error("Heartbeat hook reports host is inactive. No rewards for you.")
    }

    // Instance lease amount to much?
    let leaseAmount = sharedArrays.support.currentValues[i].leaseAmount
    let hostMaxLeaseAmount = sharedArrays.support.hookRequiredValues[0].hostMaxLeaseAmount
    let currentLeaseRatio = (leaseAmount / hostMaxLeaseAmount) // number
    let critLeaseRatioString = process.env.LEASE_CRIT // string
    let critLeaseRatio = parseFloat(critLeaseRatioString) // number
    if (sharedArrays.support.myNodes[i].leaseAmountOk) {
      logger.info(`leaseAmount of ${leaseAmount} is less than current hostMaxLeaseAmt of ${hostMaxLeaseAmount.toFixed(6)} with a ratio of ${currentLeaseRatio.toFixed(2)}. Now checking critLeaseRatio trigger...`)
      if (sharedArrays.support.myNodes[i].leaseAmountRatioOk) {
        logger.info(`currentLeaseRatio of ${currentLeaseRatio.toFixed(2)} is less than critLeaseRatio of ${critLeaseRatio}.`)
      } else {
        logger.warning(`currentLeaseRatio of ${currentLeaseRatio.toFixed(2)} is greater than critLeaseRatio of ${critLeaseRatio}. Suggest you lower leaseAmount per instance to ensure continued rewards.`)
      }
    } else {
      logger.error(`leaseAmount of ${leaseAmount} is greater than current hostMaxLeaseAmt of ${hostMaxLeaseAmount.toFixed(6)} with a ratio of ${currentLeaseRatio.toFixed(2)}. No rewards for you.`)
    }

    // Instance count less than required?
    let maxInstances = sharedArrays.support.currentValues[i].maxInstances
    let hostMinInstanceCount = sharedArrays.support.hookRequiredValues[0].hostMinInstanceCount
    if (maxInstances >= hostMinInstanceCount) {
      logger.info(`Current instances of ${maxInstances} is greater than or equal to the current hostMinInstanceCount of ${hostMinInstanceCount}.`)
    } else {
      logger.error(`[ERROR] Current instances of ${maxInstances} is less than the current hostMinInstanceCount of ${hostMinInstanceCount}. No rewards for you.`)
    }

    // Reputation less than required?
    let hostReputation = sharedArrays.support.currentValues[i].hostReputation
    let hostReputationThreshold = sharedArrays.support.hookRequiredValues[0].hostReputationThreshold
    if (hostReputation >= hostReputationThreshold) {
      logger.info(`Current hostReputation of ${hostReputation} is greater than or equal to the current hostReputationThreshold of ${hostReputationThreshold}.`)
    } else {
      logger.error(`Current hostReputation of ${hostReputation} is less than the current hostReputationThreshold of ${hostReputationThreshold}. No rewards for you.`)
    }

  } catch (err) {
    logger.debug('Error in alertMessages: ', err)
  }

}

  module.exports = {
    toggleAlert
}