BaseView = require '../lib/base_view'

module.exports = class FirstSyncView extends BaseView

    className: 'list'
    template: require '../templates/first_sync'

    events: ->
        'tap #btn-end': 'end'

    getRenderData: () ->
        step = app.replicator.get 'initialReplicationStep'
        console.log "onChange : #{step}"

        if step is 3
            messageText = t 'ready message'
            buttonText = t 'end'
        else
            messageText = t "message step #{step}"
            buttonText = t 'waiting...'
        #@render()
        return {messageText, buttonText}

    initialize: ->
        @listenTo app.replicator, 'change:initialReplicationStep', @onChange

    onChange: (replicator) ->
        step = replicator.get 'initialReplicationStep'
        @$('#finishSync .progress').text t "message step #{step}"
        @render() is step is 3

    end: ->
        step = parseInt(app.replicator.get('initialReplicationStep'))
        console.log "end #{step}"
        return if step isnt 3

        app.isFirstRun = false

        app.regularStart()
