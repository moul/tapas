http = module.exports.http = require 'http'
coffee = module.exports.helpers = require 'coffee-script'

defaultConfig =
        port: 3000
        cookie_secret: null
        session: true
        cookie: true
        stylus: true
        compress: true
        cache: true

module.exports = (kickstart2) ->
        express = kickstart2.express
        app = kickstart2.app
        config = coffee.helpers.merge defaultConfig, kickstart2.config

        app.configure ->
                app.set 'port', (process.env.PORT || config.port)
                app.set 'views', "#{__dirname}/views"
                app.set 'view options', { layout: true }
                app.set 'view engine', 'hjs'
                app.use express.favicon("#{__dirname}/public/favicon.ico", { maxAge: 86400 * 1000 })
                app.use express.logger('dev')
                app.use express.bodyParser()
                app.use express.methodOverride()
                if config.session or config.cookie
                        app.use express.cookieParser(config.cookie_secret || require('./utils').uniqueId(12))
                if config.session
                        app.use express.session()
                app.use app.router
                if config.stylus
                        app.use require('stylus').middleware("#{__dirname}/public")
                if config.cache
                        app.use express.staticCache()
                if config.compress
                        app.use express.compress()
                app.use express.static("#{__dirname}/public", { maxAge: 86400 * 1000 })

        app.configure 'development', ->
                app.use(express.errorHandler());

        app.configure 'production', ->
                if config.gzip
                        console.log "TODO: gzip"
                        #app.use gzippo.staticGzip....

        # 404, 500

        http.createServer(app).listen app.get('port'), ->
                console.log("Express server listening on port " + app.get('port'));

