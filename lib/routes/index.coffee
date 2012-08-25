exports.index = (req, res) ->
        res.render 'index', { title: 'Kickstart' }

exports.login = require './login.js'
