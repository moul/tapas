exports.index = (req, res) ->
        res.render 'index', { title: 'Tapas' }

exports.login = require './login.js'
