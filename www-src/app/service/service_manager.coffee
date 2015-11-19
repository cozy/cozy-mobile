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

log = require('/lib/persistent_log')
    prefix: "ServiceManager"
    date: true

# TODO : stub !
repeatingPeriod = 1 * 60 * 1000

module.exports = class ServiceManager extends Backbone.Model

    defaults: ->
        daemonActivated: false

    initialize: ->
        config = app.replicator.config
        # Initialize plugin with current config values.
        @listenNewPictures config, config.get 'syncImages'
        @toggle config, true # force activate.

        # Listen to updates.
        @listenTo app.replicator.config, "change:syncImages", @listenNewPictures

        @checkActivated()


    isActivated: ->
        return @get 'daemonActivated'

    checkActivated: ->
        window.JSBackgroundService.isRepeating (err, isRepeating) =>
            if err
                log.error err
                isRepeating = false

            @set 'daemonActivated', isRepeating


    activate: (repeatingPeriod) ->
        window.JSBackgroundService.setRepeating repeatingPeriod, (err) =>
            if err then return console.log err
            @checkActivated()

    deactivate: ->
        window.JSBackgroundService.cancelRepeating (err) =>
            if err then return console.log err
            @checkActivated()

    toggle: (config, activate) ->
        if activate
            @activate()
        else
            @deactivate()

    listenNewPictures: (config, listen) ->
        window.JSBackgroundService.listenNewPictures listen, (err) ->
            if err then return console.log err
