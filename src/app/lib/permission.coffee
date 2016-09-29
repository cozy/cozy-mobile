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


    checkPermission: (permission, success, callback) ->
        permission = @permissions['READ_' + permission.toUpperCase()]

        error = =>
            @config.removeSync permission
            callback()

        check = (status) =>
            if (!status.hasPermission)
                @permissions.requestPermission permission, (status) =>
                    if status.hasPermission then success() else error()
                , error
            else
                success()

        @permissions.hasPermission permission, check, error
