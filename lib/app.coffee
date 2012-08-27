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
                title: 'Kickstart2'
                site_name: 'Kickstart2'
                description: ""
        viewOptions:
                layout: false
                pretty: false
                complexNames: true
        template:
                useBootstrap: true
        ksAppConfigure: true

class ksSubApp
        constructor: (@dir, name, @parent) ->
                @path = "#{@dir}/#{name}"
                console.log "#{@path}: autodiscovering"
                @obj = require "#{@path}"
                @name = @obj.name || name
                @prefix = @obj.prefix || ''
                @app = express()
                if @obj.engine
                        @app.set 'view engine', @obj.engine
                @app.set 'views', "#{@path}/views"
                if @obj.before
                        for path in  ["/#{name}/:#{name}_id", "/#{name}/:#{name}_id/*"]
                                @app.all path, @obj.before
                                console.log "#{@path}: ALL #{path} -> before"

                for key of @obj
                        if ~['name', 'prefix', 'engine', 'before'].indexOf(key)
                                continue
                        switch key
                                when "show"
                                        method = 'get'
                                        path = "/#{name}/:${name}_id"
                                when "list"
                                        method = "get"
                                        path = "/#{name}s"
                                when 'edit'
                                        method = 'get'
                                        path = "/#{name}/:${name}_id/edit"
                                when 'update'
                                        method = 'put'
                                        path = "/#{name}/:${name}_id"
                                when 'create'
                                        method = 'post'
                                        path = "/{#name}"
                                when 'index'
                                        method = 'get'
                                        path = '/'
                                else
                                        throw new Error "Unrecognized route: #{name}.#{key}"
                        path = @prefix + path
                        console.log "#{@path}: handler #{method}(#{path}) -> #{typeof(@obj[key])}"
                        @app[method] path, @obj[key]
                @parent.use @app

class ksApp
        subapps: {}

        constructor: (@ks) ->
                @config = coffee.helpers.merge defaultConfig, @ks.config
                @config.locals = coffee.helpers.merge defaultConfig.locals, @config.locals
                @process = process
                do @ksAppInit
                if @config.ksAppConfigure
                        do @ksAppConfigure

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

        restrict: (req, res, next) =>
                if req.session.user
                        do next
                else
                        req.session.error = "Access denied !"
                        res.redirect "/login"

        autodiscover: (dir) =>
                fs.readdirSync(dir).forEach (name) =>
                        if dir[0] != '/'
                                dir = "#{@config.dirname}/#{dir}"
                        @subapps["#{dir}/#{name}"] = new ksSubApp dir, name, @

        ksAppConfigure: =>
                for dir in @config.dirs
                        pathname = "#{dir}/views"
                        if exists(pathname)
                                @set 'views', pathname
                                break
                @set 'view options', @config.viewOptions
                @set 'view engine', @config.viewEngine

                # res.message 'status message'
                @app.response.message = (msg, type = 'default') ->
                        sess = @req.session
                        sess.messages = sess.messages || {}
                        sess.messages[type] = sess.messages[type] || []
                        sess.messages[type].push msg
                        return @

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

                        @use (req, res, next) ->
                                msgs = req.session.messages || {}
                                count = 0
                                count += msgs[type].length for type of msgs
                                res.locals.messages = msgs
                                res.locals.hasMessages = !!count
                                req.session.messages = {}
                                do next

                # TODO: @use extras.fixIP ['x-forwarded-for', 'forwarded-for', 'x-cluster-ip']


                # TODO: faire un @use qui ajoute des valeurs globales (title, options)
                # TODO: ajouter express-extras
                # TODO: voir pour utiliser process.cwd
                # 404, 500

                #for dir in @config.dirs
                #        @use express.compiler
                #                src: "#{dir}/public", enable: ["less"]

                @use @app.router

                #@app.dynamicHelpers
                #        bli: (req) ->
                #                return 'salut'

                if @config.stylus
                        stylus = require 'stylus'
                        image_paths = "#{dir}/public/images" for dir in @config.dirs
                        for dir in @config.dirs
                                @use stylus.middleware
                                        debug: true
                                        src: "#{dir}/public"
                                        dest: "#{dir}/public"
                                        compile: (str, path) ->
                                                s = stylus str
                                                s.set 'filename', path
                                                s.set 'warn', true
                                                s.set 'compress', true
                                                s.define 'img', stylus.url
                                                        paths: image_paths
                                                        limit: 1000000
                                                return s

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
                @app.use (err, req, res, next) ->
                        if ~err.message.indexOf 'not found'
                                return next()
                        console.error err.stack
                        res.status(500).render('5xx')
                @app.use (req, res, next) ->
                        res.status(404).render('404', { title: "404: Not Found", url: req.originalUrl })

                @http = http.createServer @app
                port = @process.env.PORT || @config.port
                @http.listen port, -> console.log "Express server listening on port #{port}"

module.exports = ksApp.create
