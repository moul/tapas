express = module.exports.express = require 'express'

module.exports.app = express()

module.exports.runApp           = -> require('./runApp')(module.exports)
module.exports.runCron          = -> require('./runCron')(module.exports)
module.exports.runStream        = -> require('./runStream')(module.exports)
