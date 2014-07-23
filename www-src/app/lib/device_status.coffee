
callbacks = []
initialized = false
readyForSync = null

onBatteryStatus = (battery) ->
    console.log "STATUS UPDATE #{battery.level} #{battery.isPlugged} #{navigator.connection.type is Connection.WIFI}"

    batteryOk = (battery.level > 40 or battery.isPlugged)
    networkOk = navigator.connection.type is Connection.WIFI or not app.replicator.config.syncOnWifi

    readyForSync = batteryOk and networkOk
    callback null, readyForSync for callback in callbacks
    callbacks = []

module.exports.checkReadyForSync = (callback) ->
    if readyForSync? then callback null, readyForSync
    else if window.isBrowserDebugging then callback null, true
    else callbacks.push callback

    unless initialized
        window.addEventListener 'batterystatus', onBatteryStatus, false
        initialized = true



