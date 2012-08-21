config = require './config'
express = require 'express'
routes = require './routes'
http = require 'http'

app = module.exports = express()

app.configure ->
        app.set 'port', (config.port || process.env.PORT || 3000)
        app.set 'views', "#{__dirname}/views"
        app.set 'view options', { layout: true }
        app.set 'view engine', 'hjs'
        app.use express.favicon()
        app.use express.logger('dev')
        app.use express.bodyParser()
        app.use express.methodOverride()
        app.use express.cookieParser(config.cookie_secret)
        app.use express.session()
        app.use app.router
        app.use require('stylus').middleware("#{__dirname}/public")
        app.use express.static("#{__dirname}/public")

app.configure 'development', ->
        app.use(express.errorHandler());

app.get '/', routes.index
app.get '/login', routes.login.login

http.createServer(app).listen app.get('port'), ->
        console.log("Express server listening on port " + app.get('port'));

