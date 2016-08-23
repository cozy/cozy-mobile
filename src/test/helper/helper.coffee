database = require './database'
fixture = require './fixture'


module.exports =


    requireTestFile: (filename) ->
        require '../../app' + filename.split('unit')[1]


    database: database
    fixture: fixture
