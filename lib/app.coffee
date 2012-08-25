http =          require 'http'
express =       require 'express'
coffee =        require 'coffee-script'
path =          require 'path'
fs =            require 'fs'
connect =       require 'connect'
utils =         require './utils'
exists =        fs.existsSync || path.existsSync
defaultConfig =
        dirname: process.cwd() || __dirname
        dirs: [process.cwd(), __dirname]
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
        staticMaxAge: 86400
        locals:
                site_name: 'Kickstart2'
        viewOptions:
                layout: false
                pretty: false
                complexNames: true
        template:
                useBootstrap: true
        ksAppConfigure: true

class ksApp
        constructor: (@ks) ->
                @config = coffee.helpers.merge defaultConfig, @ks.config
                @process = process
                @ksAppInit()
                if @config.ksAppConfigure
                        @ksAppConfigure()

        @create: (ks) ->
                return new ksApp(ks)

        ksAppInit: =>
                @app = express()

        # wrappers
        use: =>         @app.use.apply(@app, arguments)
        get: =>         @app.get.apply(@app, arguments)
        set: =>         @app.set.apply(@app, arguments)
        listen: =>      @app.listen.apply(@app, arguments)
        post: =>        @app.post.apply(@app, arguments)
        configure: =>   @app.configure.apply(@app, arguments)

        ksAppConfigure: =>
                for dir in @config.dirs
                        pathname = "#{dir}/views"
                        if exists(pathname)
                                @set 'views', pathname
                                break
                @set 'view options', @config.viewOptions
                @set 'view engine', @config.viewEngine
                if @config.viewOptions.pretty
                        @app.locals.pretty = true
                for dir in @config.dirs
                        pathname = "#{dir}/public/favicon.ico"
                        if exists(pathname)
                                @use express.favicon(pathname, { maxAge: @config.staticMaxAge * 1000 })
                                break
                @use express.logger('dev')
                @use express.bodyParser()
                @use express.methodOverride()

                if @config.session or @config.cookie
                        @use express.cookieParser(@config.cookie_secret || utils.uniqueId(12))
                if @config.session
                        @use express.session(@config.session_secret || utils.uniqueId(12))

                # TODO: @use extras.fixIP ['x-forwarded-for', 'forwarded-for', 'x-cluster-ip']


                # TODO: faire un @use qui ajoute des valeurs globales (title, options)
                # TODO: ajouter express-extras
                # TODO: voir pour utiliser process.cwd
                # 404, 500

                @use @app.router
                if @config.stylus
                        @use require('stylus').middleware("#{@config.dirname}/public")

                #if config.cache
                #        @use express.staticCache()

                if @config.compress
                        @use express.compress()

                # TODO: auto-compile coffee

                @app.locals = @config.locals

                for dir in @config.dirs
                        @use express.static("#{dir}/public", { maxAge: @config.staticMaxAge * 1000 })

                @configure 'development', =>
                        @use express.errorHandler()
                        @app.locals.pretty = true

                @configure 'production', =>
                        if @config.compress
                                console.log "TODO: compress gzip"
                                #@use gzippo.staticGzip....


        run: =>
                @http = http.createServer @app
                port = @process.env.PORT || @config.port
                @http.listen port, -> console.log "Express server listening on port #{port}"

module.exports = ksApp.create
