log = require('/lib/persistent_log')
    prefix: "device status"
    date: true

# Store callbacks, while waiting (with timeout) for battery event.
callbacks = []
battery = null
timeout = false

DATA_CONSUMPTION_THRESHOLD = 100 # MB

checkConsumption = (callback)->
    # Stub
    unless navigator.trafficstats?
        return callback null, true

    navigator.trafficstats.getTxBytes (err, txBytes) ->
        return callback err if err
        navigator.trafficstats.getRxBytes (err, rxBytes) ->
            return callback err if err
            txMB = Math.round txBytes / 1000000
            rxMB = Math.round rxBytes / 1000000

            log.debug "Tx: #{txMB}MB ; Rx: #{rxMB}MB"
            return callback null, (txMB + rxMB) < DATA_CONSUMPTION_THRESHOLD


# Dispatch on each callback.
callbackWaiting = (err, ready, msg) ->
    callback err, ready, msg  for callback in callbacks
    callbacks = []


onBatteryStatus = (newStatus) =>
    # timeout watchdog isn't usefull anymore, so we turn the flag
    timeout = false
    battery = newStatus
    checkReadyForSync()

# Register to battery events. To call after 'deviceRedy' event.
module.exports.initialize = ->
    if timeout or battery? # Avoid multiples calls to addEventListener
        log.info "already initialized"
        return

    timeout = true

    log.info "initialize device status."
    window.addEventListener 'batterystatus', onBatteryStatus


module.exports.shutdown = ->
    window.removeEventListener 'batterystatus', onBatteryStatus

# Check if device is ready for heavy works:
# - battery as more than 20%
# - on wifi if syncOnWifi[only] options is activated.
# - data consumption since last reboot under 100MB
# Callback should have (err, (boolean)ready, message) signature.
module.exports.checkReadyForSync = checkReadyForSync = (callback)->

    if window.isBrowserDebugging
        return callback null, true

    callbacks.push callback if callback?

    # if we don't have informations about battery status, wait for it
    # with a 4" timeout.
    unless battery? #
        setTimeout () =>
            if timeout
                # We reached timeout, and a batterystatus event hasn't fired yet
                callbackWaiting new Error "No battery informations"
        , 4 * 1000

        return

    checkConsumption (err, isFine) ->
        return callbackWaiting err if err

        unless isFine
            return callbackWaiting null, false, 'too much data comsuption'

        unless (battery.level > 20 or battery.isPlugged)
            log.info "NOT ready on battery low."
            return callbackWaiting null, false, 'no battery'
        if app.replicator.config.get('syncOnWifi') and
           (not (navigator.connection.type is Connection.WIFI))
            log.info "NOT ready on no wifi."
            return callbackWaiting null, false, 'no wifi'

        log.info "ready to sync."
        callbackWaiting null, true
