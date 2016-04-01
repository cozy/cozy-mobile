mocha.setup
    ui: 'bdd'


application = require 'test/application'


module.exports = ->
    mocha.checkLeaks()
    mocha.run()
