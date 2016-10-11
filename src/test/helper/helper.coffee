database = require './database'
fixture = require './fixture'
config = require './config'


module.exports =


    requireTestFile: (filename) ->
        require '../../app' + filename.split('unit')[1]


    database: database
    fixture: fixture
    config: config
