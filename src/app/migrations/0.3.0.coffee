module.exports =


    migrate: (callback) ->
        navigator.notification.alert t 'version too old'
        app.exit()
