module.exports = ks     = () ->

ks.config               = {}
ks.app                  = -> require('./app')   ks
ks.cron                 = -> require('./cron')  ks
ks.sream                = -> require('./sream') ks
