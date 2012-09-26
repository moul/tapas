class Kickstart2
        constructor: (@config) ->

        @create: (config) ->
                new Kickstart2 config

        app: () =>
                require('./app') @

        cron: () =>
                require('./cron') @

        worker: () =>
                require('./worker') @



module.exports = Kickstart2.create
module.exports.utils = require('./utils')
