
callbacks = []
initialized = false
readyForSync = null
readyForSyncMsg = ""
battery = null

callbackWaiting = (err, ready, msg) ->
    readyForSync = ready
    readyForSyncMsg = msg
    callback err, ready, msg  for callback in callbacks
    callbacks = []

update = ->
    return unless battery?

    unless (battery.level > 20 or battery.isPlugged)
        return callbackWaiting null, false, 'no battery'

    if app.replicator.config.get('syncOnWifi') and
    not navigator.connection.type is Connection.WIFI
        return callbackWaiting null, false, 'no wifi'

    callbackWaiting null, true

module.exports.checkReadyForSync = (callback) ->
    if readyForSync?
        callback null, readyForSync, readyForSyncMsg
    else if window.isBrowserDebugging
        callback null, true
    else
        callbacks.push callback
    unless initialized
        timeout = true
        setTimeout () =>
            if timeout
                timeout = false
                initialized = false
                callback null, true
        , 4 * 1000
        window.addEventListener 'batterystatus', (newStatus) =>
            if timeout
                timeout = false
                battery = newStatus
                update()
        , false
        app.replicator.config.on 'change:syncOnWifi', update
        initialized = true


