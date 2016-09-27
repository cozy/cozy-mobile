async = require 'async'
log = require("./persistent_log")
    prefix: "NotificationHandler"
    date: true


instance = null


module.exports = class NotificationHandler


    constructor: (@replicateDb, @plugin) ->
        return instance if instance
        instance = @
        @replicateDb ?= window.app.init.database.replicateDb
        @cordovaPlugin ?= cordova.plugins.notification.local

        @listenCordovaPlugin()


    getCordovaId: (cozyNotif, callback) ->
        log.debug "getCordovaId"

        # generate id : android require an 'int' id, we generate it from the
        # too long couchDB _id.
        cordovaId = parseInt cozyNotif._id.slice(-7), 16
        if isNaN cordovaId # if id wasn't an hexa chain, fallback on timestamp.
            cordovaId = cozyNotif.publishDate % 10000000

        callback null, cordovaId


    deleteOnDatabase: (cordovaNotif, callback) ->
        log.debug "deleteOnDatabase"

        data = JSON.parse cordovaNotif.data

        @replicateDb.get data._id, (err, cozyNotif) =>
            return callback err if err
            if cozyNotif._deleted
                callback()
            else
                cozyNotif._deleted = true
                @replicateDb.put cozyNotif, callback


    deletesIfIsNotPresent: (callback) ->
        log.debug "deletesIfIsNotPresent"

        @cordovaPlugin.getAll (cordovaNotifs) =>
            async.eachSeries cordovaNotifs, (cordovaNotif, cb) =>
                @cordovaPlugin.isPresent cordovaNotif.id, (isPresent) =>
                    return cb() if isPresent
                    @deleteOnDatabase cordovaNotif, cb
            , callback


    removeCordovaNotification: (cozyNotif, callback) ->
        log.debug "removeCordovaNotification"

        @getCordovaId cozyNotif, (err, cordovaId) =>
            @cordovaPlugin.isPresent cordovaId, (isPresent) =>
                if isPresent
                    @cordovaPlugin.clear cordovaId, callback
                else
                    callback()


    displayCordovaNotification: (cozyNotif, callback) ->
        log.debug "displayCordovaNotification"

        appName = cozyNotif.app or cozyNotif.resource.app or 'Notification'
        title = "Cozy - #{appName}"

        @getCordovaId cozyNotif, (err, cordovaId) =>
            cordovaNotif =
                id: cordovaId
                title: title
                text: cozyNotif.text
                data: { _id: cozyNotif._id }
            @cordovaPlugin.schedule cordovaNotif, (res) ->
                log.warn res unless res is 'OK'
                callback()


    listenCordovaPlugin: ->
        log.debug "listenCordovaPlugin"

        @cordovaPlugin.on 'click', (cordovaNotif) =>
            log.debug 'click'

            @deleteOnDatabase cordovaNotif, (err) ->
                log.error err if err

        @cordovaPlugin.on 'clear', (cordovaNotif) =>
            log.debug 'clear'

            @deleteOnDatabase cordovaNotif, (err) ->
                log.error err if err
