http =           require 'http'
express =        require 'express'
express_View =   require 'express/lib/view'
express_Utils =  require 'express/lib/utils'
coffee =         require 'coffee-script'
path =           require 'path'
fs =             require 'fs'
connect =        require 'connect'
jade =           require 'jade'
stylus =         require 'stylus'
nib =            require 'nib'
io =             require 'socket.io'
utils =          require './utils'
exists =         fs.existsSync || path.existsSync
defaultConfig =  require './defaultConfig'
log =            require 'socket.io/lib/logger'
hogan =          require 'hogan.js'
htc =            require 'hogan-template-compiler'
connect_assets = require 'connect-assets'

hoganTemplateRenderers = []
hoganCompilers = []

class ksSubApp
        constructor: (@dir, name, parent) ->
                #@config = coffee.helpers.merge {}, parent.config
                @config = utils.deepExtend {}, parent.config
                @config.sub =
                        parent: parent
                        path: "#{@dir}/#{name}"
                console.log "#{@config.sub.path}: autodiscovering"
                parent.setupPublic "#{@config.sub.path}"
                @obj = require "#{@config.sub.path}"
                @config.sub.name = @obj.name || name
                @config.sub.prefix = @obj.prefix || ''
                @config.locals.config = @config
                @config.locals.sub = @config.sub
                @app = do express
                if @obj.engine
                        @app.set 'view engine', @obj.engine
                @config.locals.dirs = @config.dirs = [@config.sub.path].concat @config.dirs[..]
                @app.set 'views', ["#{dir}/views" for dir in @config.dirs][0]

                if @obj.before
                        for pathname in  ["/#{@config.sub.name}/:#{@config.sub.name}_id", "/#{@config.sub.name}/:#{@config.sub.name}_id/*"]
                                @app.all "#{@config.sub.prefix}#{pathname}", @obj.before
                                console.log "#{@config.sub.prefix}#{pathname}: ALL #{pathname} -> before"

                if @obj.locals
                        utils.deepExtend @config.locals, @obj.locals

                for key of @obj
                        if ~['name', 'prefix', 'engine', 'before', 'locals', 'custom'].indexOf key
                                continue
                        switch key
                                when "show_json"
                                        method = 'get'
                                        pathname = "/#{@config.sub.name}/:#{@config.sub.name}_id/json"
                                when "show"
                                        method = 'get'
                                        pathname = "/#{@config.sub.name}/:#{@config.sub.name}_id"
                                when "list"
                                        method = "get"
                                        pathname = "/#{@config.sub.name}s"
                                when "list_json"
                                        method = "get"
                                        pathname = "/#{@config.sub.name}s/json"
                                when 'edit'
                                        method = 'get'
                                        pathname = "/#{@config.sub.name}/:#{@config.sub.name}_id/edit"
                                when 'update'
                                        method = 'put'
                                        pathname = "/#{@config.sub.name}/:#{@config.sub.name}_id"
                                when 'create'
                                        method = 'post'
                                        pathname = "/{#@config.sub.name}"
                                when 'index'
                                        method = 'get'
                                        pathname = '/'
                                else
                                        console.error "Unrecognized route: #{@config.sub.name}.#{key}"
                                        #throw new Error "Unrecognized route: #{@config.sub.name}.#{key}"
                        pathname = @config.sub.prefix + pathname
                        console.log "#{@config.sub.path}: handler #{method}(#{pathname}) -> #{typeof(@obj[key])}"
                        @app[method] pathname, @obj[key]
                if @obj.custom?
                        for entry in @obj.custom
                                utils.deepExtend entry, {
                                        method: 'get'
                                        path: null
                                        callback: null
                                        }
                                console.log "#{@config.sub.path}: custom handler #{entry.method}(#{entry.path} -> #{typeof(entry.callback)})"
                                @app[entry.method] entry.path, entry.callback
                @app.locals = @config.locals
                #@app.use express.compiler { src: "#{@config.sub.path}/public", enable: ["coffeescript"] }
                parent.use @app
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
                @config.locals.dirs = @config.dirs
                @process = process
                @log = new (log)()
                do @ksAppInit
                if @config.ksAppConfigure
                        do @ksAppConfigure

        @create: (ks) ->
                return new ksApp(ks)

        ksAppInit: =>
                @express = @app = do express
                @http = http.createServer @app
                #@io = null
                @io = io.listen @http
                @io.enable 'browser client minification'
                @io.enable 'browser client etag'
                @io.enable 'browser client gzip'
                @io.set 'log level', 5


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

                require('jade').Parser.prototype.parseExtends = ->
                        path = require 'path'
                        fs = require 'fs'
                        if not @filename
                                throw new Error 'the "filename" option is required to extend templates'
                        shortpath = @expect('extends').val.trim()
                        dirs = "#{dir}/views" for dir in @options.dirs
                        dirs = [path.dirname @filename].concat dirs
                        for dir in dirs
                                pathname = path.join dir, "#{shortpath}.jade"
                                if exists pathname
                                        break
                        str = fs.readFileSync pathname, 'utf8'
                        parser = new jade.Parser str, pathname, @options
                        parser.blocks = @blocks
                        parser.contexts = @contexts
                        @extending = parser
                        new jade.nodes.Literal ''

                jade.filters.testManfred = (block, compiler) ->
                        new ksExtendsJadeFilter block, compiler.options

                @set 'views', ["#{dir}/views" for dir in @config.dirs][0]
                # multiple views
                lookupProxy = express_View::lookup
                lookupProxy = (pathname) ->
                        ext = @ext
                        if !express_Utils.isAbsolute pathname
                                pathname = path.join @root, pathname
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
                @app.response.message = (msg, type = 'info') ->
                        sess = @req.session
                        sess.messages = sess.messages || {}
                        sess.messages[type] = sess.messages[type] || []
                        sess.messages[type].push msg
                        return @

                if @config.viewOptions.pretty
                        @config.locals.pretty = true
                @use express.logger('dev')
                @use express.bodyParser()
                @use express.methodOverride()

                for dir in @config.dirs
                        @setupPublic dir

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


                #if config.cache
                #        @use express.staticCache()

                if @config.compress
                        @use express.compress()

                # TODO: auto-compile coffee

                @configure 'development', =>
                        @use express.errorHandler()
                        @config.locals.pretty = true

                @configure 'production', =>
                        if @config.compress
                                console.log "TODO: compress gzip"
                                #@use gzippo.staticGzip....
                @app.locals = @config.locals

                @app.get '/templates.js', (req, res) ->
                        res.contentType 'application/javascript'
                        # TODO: aggregate multiple modules hogans !
                        for htr in hoganTemplateRenderers
                                console.log htr
                                res.send htr.getSharedTemplates()
                                return
                        res.write ';'

        setupPublic: (dir) =>
                parent_name = utils.getParentFolderName(dir, ["lib"])
                @config.locals["#{parent_name}_assets"] = global[parent_name] = context = {}

                favicon = "#{dir}/public/favicon.ico"
                if exists favicon
                        @use express.favicon(favicon, { maxAge: @config.staticMaxAge * 1000 })
                if @config.connect_assets
                        if exists "#{dir}/public"
                                console.log "ASSETS #{dir}/public"
                                middleware = connect_assets
                                        src: "#{dir}/public"
                                        helperContext: context
                                @use middleware
                                context.css.root = '.'
                                context.img.root = '.'
                                context.js.root = '.'
                if @config.stylus
                        console.log "setup public: #{dir}/public"
                        image_paths = "#{_dir}/public/images" for _dir in @config.dirs
                        @use stylus.middleware
                                debug: @config.debug
                                src: "#{dir}/public"
                                dest: "#{dir}/public"
                                #force: true
                                compile: (str, path, fn) ->
                                        s = stylus str
                                        s.set 'filename', path
                                        s.set 'warn', true
                                        s.set 'compress', true
                                        #s.use do nib
                                        s.define 'img', stylus.url
                                                paths: image_paths
                                                limit: 1000000
                                        if fn?
                                                s.render fn
                                        return s

                if @config.hogan # && in development
                        pathname = "#{dir}/public/partials"
                        console.log "setup hogan: #{pathname}"
                        if exists pathname
                                hoganTemplateRenderer = htc
                                        partialsDirectory: pathname
                                        layoutsDirectory: pathname
                                hoganTemplateRenderers.push hoganTemplateRenderer
                                hoganCompilers.push
                                        compile: (source, options) ->
                                                template = hoganTemplateRenderer.getTemplate options.filename
                                                return (locals) ->
                                                        return template.render locals, hoganTemplateRenderer.getPartials()

                @use express.static("#{dir}/public", { maxAge: @config.staticMaxAge * 1000 })

        run: =>
                @configure 'development', =>
                        @use (req, res, next) ->
                                for htr in hoganTemplateRenderers
                                        console.log htr
                                        htr.read()
                                next()

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

                port = @process.env.PORT || @config.port
                @http.listen port, -> console.log "Tapas server listening on port #{port}"
                process.on 'uncaughtException', @log.error.bind(@log)
                @log.info 'Tapas server started'

module.exports = ksApp.create
