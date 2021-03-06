// Generated by CoffeeScript 1.6.2
(function() {
  var Tapas,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  Tapas = (function() {
    function Tapas(config) {
      this.config = config;
      this.worker = __bind(this.worker, this);
      this.cron = __bind(this.cron, this);
      this.app = __bind(this.app, this);
    }

    Tapas.create = function(config) {
      return new Tapas(config);
    };

    Tapas.prototype.app = function() {
      return require('./app')(this);
    };

    Tapas.prototype.cron = function() {
      return require('./cron')(this);
    };

    Tapas.prototype.worker = function() {
      return require('./worker')(this);
    };

    return Tapas;

  })();

  module.exports = Tapas.create;

  module.exports.utils = require('./utils');

}).call(this);
