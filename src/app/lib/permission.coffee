instance = null
log = require('./persistent_log')
    prefix: "Permission"
    date: true


module.exports = class Permission


    constructor: () ->
        return instance if instance
        instance = @

        @config = app.init.config
        @permissions = cordova.plugins.permissions
        @synchro = app.synchro


    checkPermission: (type, success, callback) ->

        if device.platform is 'iOS'
            success true

        if type is 'calendars'
            permission = 'CALENDAR'
        else if type is 'files' or type is 'photos'
            permission = 'EXTERNAL_STORAGE'
        else if type is 'contacts'
            permission = 'CONTACTS'

        readPermission = @permissions['READ_' + permission]
        writePermission = @permissions['WRITE_' + permission]

        error = (err) =>
            log.info 'err', err
            @config.removeSync type
            callback false

        read = (status) =>
            if (!status.hasPermission)
                @permissions.requestPermission readPermission, (status) =>
                    if status.hasPermission then checkWritePermission() else error()
                , error
            else
                checkWritePermission()

        write = (status) =>
            if (!status.hasPermission)
                @permissions.requestPermission writePermission, (status) =>
                    if status.hasPermission then success true else error()
                , error
            else
                success true

        checkWritePermission = =>
            @permissions.hasPermission writePermission, write, error

        @permissions.hasPermission readPermission, read, error
