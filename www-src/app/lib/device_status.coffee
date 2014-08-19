
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
    if readyForSync? then callback null, readyForSync, readyForSyncMsg
    else if window.isBrowserDebugging then callback null, true
    else callbacks.push callback

    unless initialized
        window.addEventListener 'batterystatus', (newStatus) =>
            battery = newStatus
            update()
        , false
        app.replicator.config.on 'change:syncOnWifi', update
        initialized = true



