class Tapas
        constructor: (@config) ->

        @create: (config) ->
                new Tapas config

        app: () =>
                require('./app') @

        cron: () =>
                require('./cron') @

        worker: () =>
                require('./worker') @



module.exports = Tapas.create
module.exports.utils = require('./utils')
