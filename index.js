require('dotenv').config();
const path = require('path');
const Logger = require("@ptkdev/logger")
const cron = require('node-cron');
const { createDirectoryIfNotExists } = require('./utils/createDirectory');
const { checkGas } = require('./main/checkGas');
const { toggleAlert } = require('./main/toggleAlert');
const { checkStatus } = require('./main/checkStatus');
const { createMainArray, createSupportArrays } = require('./utils/createArrays');
const sharedArrays = require('./shared/sharedArrays');
const { cleanUpWorkingDirectory } = require('./utils/cleanupFiles');

const logOptions = {
	language: "en", // en / it / pl / es / pt / de / ru / fr
	colors: true,
	debug: true,
	info: true,
	warning: true,
	error: true,
	sponsor: false,
	write: true,
	type: "log",
	rotate: {
		size: "10M",
		encoding: "utf8",
	},
	path: {
		debug_log: "./logs/evernode-uptimerobot-monitor.log",
        error_log: "./logs/working/error.log",
        warning_log: "./logs/working/warning.log",
	},
};

(async () => {
    try {
        const rootPath = process.cwd();
        const folderPath = path.join(rootPath, 'logs');
        await createDirectoryIfNotExists(folderPath);
        const logger = new Logger(logOptions);
        const main = await createMainArray()
        sharedArrays.support = await createSupportArrays()

        if (process.env.LEASE_CRIT > 1) {
            console.log("Check .env, the LEASE_CRIT ratio must be 1 or less. Aborting.")
            process.exit(1); // Exit the current process
        }

        //const monitorNode = cron.schedule(process.env.CRON_SCHED, async () => {
            await checkGas(sharedArrays)
            await checkStatus(sharedArrays)
            await toggleAlert(sharedArrays, logger)
            const workingDir = `${folderPath}/working`
            await cleanUpWorkingDirectory(workingDir)
        //}

    } catch (error) {
        console.error("Some error: ", error)
    }
})();