database = require './database'
device = require './device'


module.exports =


    getDatabase: ->
        database.getDatabase new Date().toISOString()


    getAndroidDevice: ->
        device.getAndroidDevice()
