# Service lifecycle
#
# Service is started on :
#   Repeatedly
#
#   if syncImage
#       New Picture Intent
#       New connection on Wifi
#
# Service do
#   if Wifi
#       Backup images (if syncImages)
#       Sync
#       Update cache
#
#   if cozyNotifications
#       Sync notifications
#       Display notifications
#

log = require('../lib/persistent_log')
    prefix: "ServiceManager"
    date: true

repeatingPeriod = 15 * 60 * 1000

module.exports = class ServiceManager extends Backbone.Model

    defaults: ->
        daemonActivated: false

    initialize: ->
        log.debug "initialize"

        config = app.init.config
        # Initialize plugin with current config values.
        @listenNewPictures config, config.get 'syncImages'
        @toggle config, true # force activate.

        # Listen to updates.
        @listenTo config, "change:syncImages", @listenNewPictures

        @checkActivated()


    isActivated: ->
        log.debug "isActivated"

        return @get 'daemonActivated'

    checkActivated: ->
        log.debug "checkActivated"

        window.JSBackgroundService.isRepeating (err, isRepeating) =>
            if err
                log.error err
                isRepeating = false

            @set 'daemonActivated', isRepeating


    activate: (repeatingPeriod) ->
        log.debug "activate: repeatingPeriod=#{repeatingPeriod}"

        window.JSBackgroundService.setRepeating repeatingPeriod, (err) =>
            return log.error err if err
            @checkActivated()

    deactivate: ->
        log.debug "deactivate"

        window.JSBackgroundService.cancelRepeating (err) =>
            return log.error err if err
            @checkActivated()

    toggle: (config, activate) ->
        log.debug "toggle: activate=#{activate}"

        if activate
            @activate repeatingPeriod
        else
            @deactivate()

    listenNewPictures: (config, listen) ->
        log.debug "listenNewPictures"

        window.JSBackgroundService.listenNewPictures listen, (err) ->
            log.error err if err

    isRunning: (callback) ->
        log.debug "isRunning"

        window.JSBackgroundService.isRunning callback
