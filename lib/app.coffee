module.exports = ksApp =       (_ks) -> ksApp.ks = _ks
ksApp.http = http =             require 'http'
ksApp.express = express =       require 'express'
ksApp.coffee = coffee =         require 'coffee-script'
ksApp.path = path =             require 'path'
ksApp.fs = fs =                 require 'fs'
ksApp.connect = connect =       require 'connect'
ksApp.exists = exists =         fs.existsSync || path.existsSync
ksApp.ks = ks =                 null
ksApp.app = app =               null
ksApp.config = config =         {}
ksApp.defaultConfig =
        port: 3000
        cookie_secret: null
        session_secret: null
        session: true
        cookie: true
        stylus: true
        less: false
        compress: true
        cache: true
        viewEngine: 'jade' #hjs
        viewOptions:
                layout: false
                pretty: false
                complexNames: true
        staticMaxAge: 86400
        template:
                useBootstrap: true

ksApp.initialize = () ->
        app = express()
        ksApp.config = config = coffee.helpers.merge ksApp.defaultConfig, ksApp.kskickstart2.config
        dirName = process.cwd() || __dirname

        app.configure ->
                app.set 'port', (process.env.PORT || config.port)
                for pathName in ["#{dirName}/views", "#{__dirname}/views"]
                        if exists(pathName)
                                app.set 'views', pathName
                                break
                app.set 'view options', config.viewOptions
                app.set 'view engine', config.viewEngine
                if config.viewOptions.pretty
                        app.locals.pretty = true

                for pathName in ["#{dirName}/public/favicon.ico", "${__dirname}/public/favicon.ico"]
                        if exists(pathName)
                                app.use express.favicon(pathName, { maxAge: config.staticMaxAge * 1000 })
                                break

                app.use express.logger('dev')
                app.use express.bodyParser()
                app.use express.methodOverride()

                if config.session or config.cookie
                        app.use express.cookieParser(config.cookie_secret || require('./utils').uniqueId(12))
                if config.session
                        app.use express.session(config.session_secret || require('./utils').uniqueId(12))

                # TODO: app.use extras.fixIP ['x-forwarded-for', 'forwarded-for', 'x-cluster-ip']


                # TODO: faire un app.use qui ajoute des valeurs globales (title, options)
                # TODO: ajouter express-extras
                # TODO: voir pour utiliser process.cwd

                app.use app.router
                if config.stylus
                        app.use require('stylus').middleware("#{dirName}/public")

                #if config.cache
                #        app.use express.staticCache()

                if config.compress
                        app.use express.compress()

                # TODO: auto-compile coffee

                app.use express.static("#{dirName}/public", { maxAge: config.staticMaxAge * 1000 })
                app.use express.static("#{__dirname}/public", { maxAge: config.staticMaxAge * 1000 })

        app.configure 'development', ->
                app.use(express.errorHandler());
                app.locals.pretty = true

        app.configure 'production', ->
                if config.gzip
                        console.log "TODO: gzip"
                        #app.use gzippo.staticGzip....

        # 404, 500
        ksApp.get                  = app.get
        ksApp.post                 = app.post
        ksApp.use                  = app.use
        ksApp.listen               = app.listen

ksApp.start = () ->
        ks.http.createServer(app).listen app.get('port'), ->
                console.log("Express server listening on port " + app.get('port'));
