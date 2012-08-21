exports.index = (req, res) ->
        res.render 'index', { title: 'Express' }

exports.login = require './login.js'
