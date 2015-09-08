callbacks = []
initialized = false
readyForSync = null
readyForSyncMsg = ""
battery = null

log = require('/lib/persistent_log')
    prefix: "device status"
    date: true

callbackWaiting = (err, ready, msg) ->
    readyForSync = ready
    readyForSyncMsg = msg
    callback err, ready, msg  for callback in callbacks
    callbacks = []

module.exports.update = update = ->
    return unless battery?

    unless (battery.level > 20 or battery.isPlugged)
        log.info "NOT ready on battery low."
        return callbackWaiting null, false, 'no battery'
    if app.replicator.config.get('syncOnWifi') and
       (not (navigator.connection.type is Connection.WIFI))
        log.info "NOT ready on no wifi."
        return callbackWaiting null, false, 'no wifi'

    log.info "ready to sync."
    callbackWaiting null, true

module.exports.checkReadyForSync = (force, callback) ->
    # force is optionnal
    if arguments.length is 1
        callback = force
        force = false

    update() if force

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

module.exports.getStatus = () ->
    return { initialized, readyForSync, readyForSyncMsg, battery }
