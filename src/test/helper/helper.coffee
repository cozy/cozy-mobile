database = require './database'
device = require './device'
path = require 'path'


module.exports =

    requireTestFile: (filename) ->
        require '../../app' + filename.split('unit')[1]


    getDatabase: ->
        database.getDatabase new Date().toISOString()


    getAndroidDevice: ->
        device.getAndroidDevice()


    getAccount: ->
        accountName: 'accountName'
        accountType: 'accountType'


    getCozyCalendar: ->
        require '../fixtures/cozy_calendar'


    getCozyContact: ->
        require '../fixtures/cozy_contact'
