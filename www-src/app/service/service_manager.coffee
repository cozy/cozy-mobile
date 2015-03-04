
repeatingPeriod = 15 * 60 * 1000

module.exports = class ServiceManager extends Backbone.Model

    defaults: ->
        daemonActivated: false

    initialize: ->
        @checkActivated()

    isActivated: ->
        return @get 'daemonActivated'

    checkActivated: ->
        window.JSBackgroundService.isRepeating (err, isRepeating) =>
            if err
                console.log err
                isRepeating = false

            @set 'daemonActivated', isRepeating


    activate: ->
        window.JSBackgroundService.setRepeating repeatingPeriod, (err) =>
            if err then return console.log err
            @checkActivated()

    deactivate: ->
        window.JSBackgroundService.cancelRepeating (err) =>
            if err then return console.log err
            @checkActivated()

    toggle: ->
        if @get 'daemonActivated'
            @deactivate()
        else
            @activate()
