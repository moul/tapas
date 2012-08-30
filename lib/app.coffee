http =          require 'http'
express =       require 'express'
express_View =  require 'express/lib/view'
express_Utils = require 'express/lib/utils'
coffee =        require 'coffee-script'
path =          require 'path'
fs =            require 'fs'
connect =       require 'connect'
utils =         require './utils'
jade =          require 'jade'
stylus =        require 'stylus'
exists =        fs.existsSync || path.existsSync
defaultConfig =
        dirname: process.cwd() || __dirname
        dirs: [process.cwd(), __dirname]
        port: 3000
        debug: true
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
        use:
                bootstrap: true
        locals:
                title: 'Kickstart2'
                site_name: 'Kickstart2'
                description: ""
                css_libraries: []
                js_libraries: []
                use: {
                        bootstrap: {
                                fixedNavbar: true
                                }
                }
                regions: {
                        navbarItems: { '/': 'Home', '/user': 'User' }
                }
        viewOptions:
                layout: false
                pretty: false
                complexNames: true
        ksAppConfigure: true

class ksSubApp
        constructor: (@dir, name, @parent) ->
                @pathname = "#{@dir}/#{name}"
                console.log "#{@pathname}: autodiscovering"
                @obj = require "#{@pathname}"
                @name = @obj.name || name
                @prefix = @obj.prefix || ''
                @app = express()
                if @obj.engine
                        @app.set 'view engine', @obj.engine
                #@dirs = [@pathname].concat @parent.config.dirs[..]
                @dirs = @parent.config.dirs[..]
                @app.set 'views', ["#{dir}/views" for dir in @dirs][0]

                if @obj.before
                        for pathname in  ["/#{name}/:#{name}_id", "/#{name}/:#{name}_id/*"]
                                @app.all pathname, @obj.before
                                console.log "#{@pathname}: ALL #{pathname} -> before"

                for key of @obj
                        if ~['name', 'prefix', 'engine', 'before'].indexOf(key)
                                continue
                        switch key
                                when "show"
                                        method = 'get'
                                        pathname = "/#{name}/:#{name}_id"
                                when "list"
                                        method = "get"
                                        pathname = "/#{name}s"
                                when 'edit'
                                        method = 'get'
                                        pathname = "/#{name}/:#{name}_id/edit"
                                when 'update'
                                        method = 'put'
                                        pathname = "/#{name}/:#{name}_id"
                                when 'create'
                                        method = 'post'
                                        pathname = "/{#name}"
                                when 'index'
                                        method = 'get'
                                        pathname = '/'
                                else
                                        throw new Error "Unrecognized route: #{name}.#{key}"
                        pathname = @prefix + pathname
                        console.log "#{@pathname}: handler #{method}(#{pathname}) -> #{typeof(@obj[key])}"
                        @app[method] pathname, @obj[key]
                @parent.use @app
                @app.locals = @parent.config.locals
#class ksExtendsJadeFilter extends jade.Compiler
        #@__proto__ = jade.Compiler.prototype
#        @visitTag = (node) ->
#                parent = Compiler::visitTag
#                console.log '=========='
#                console.dir node



class ksApp
        subapps: {}

        constructor: (@ks) ->
                @config = coffee.helpers.merge defaultConfig, @ks.config
                @config.locals = coffee.helpers.merge defaultConfig.locals, @config.locals
                @config.locals.print_errors = @config.debug
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
                # override parseExtends
                # OU
                # ajouter un filter smartExtends

                console.dir jade.filtesr
                jade.filters.testManfred = (block, compiler) ->
                        new ksExtendsJadeFilter block, compiler.options

                @set 'views', ["#{dir}/views" for dir in @config.dirs][0]
                # multiple views
                lookupProxy = express_View::lookup
                lookupProxy = (pathname) ->
                        ext = @ext

                        console.log 'path1', pathname
                        if !express_Utils.isAbsolute pathname
                                pathname = path.join @root, pathname
                        console.log 'path2', pathname
                        if exists pathname
                                return pathname

                        pathname = path.join(path.dirname(pathname), path.basename(pathname, ext), 'index' + ext)
                        if exists pathname
                                return pathname

                express_View::lookup = (pathname) ->
                        if @root instanceof Array
                                roots = @root[..]
                                matchedView = null
                                for root in roots
                                        console.log "ROOT", root
                                        console.info "roots", roots
                                        @root = root
                                        matchedView = lookupProxy.call @, pathname
                                        if matchedView
                                                break
                                @root = roots
                                return matchedView
                        return lookupProxy.call @, pathname

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
                        @config.locals.pretty = true
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

                @use (req, res, next) ->
                        res.locals.current = req.url
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
                        image_paths = "#{dir}/public/images" for dir in @config.dirs
                        for dir in @config.dirs
                                @use stylus.middleware
                                        debug: @config.debug
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

                for dir in @config.dirs
                        @use express.static("#{dir}/public", { maxAge: @config.staticMaxAge * 1000 })

                @configure 'development', =>
                        @use express.errorHandler()
                        @config.locals.pretty = true

                @configure 'production', =>
                        if @config.compress
                                console.log "TODO: compress gzip"
                                #@use gzippo.staticGzip....
                @app.locals = @config.locals


        run: =>
                if true
                        @app.use (err, req, res, next) ->
                                if ~err.message.indexOf 'not found'
                                        return next()
                                console.log 'error, err.stack'
                                console.error err.stack
                                console.dir err
                                res.status(500).render('5xx', {title: "500: Internal Server Error", error: err, stack: err.stack})
                @app.use (req, res, next) ->
                        res.status(404).render('404', { title: "404: Not Found", url: req.originalUrl })

                @http = http.createServer @app
                port = @process.env.PORT || @config.port
                @http.listen port, -> console.log "Express server listening on port #{port}"

module.exports = ksApp.create
