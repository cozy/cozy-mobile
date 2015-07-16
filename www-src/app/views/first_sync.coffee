BaseView = require '../lib/base_view'

LAST_STEP = 5
module.exports = class FirstSyncView extends BaseView

    className: 'list'
    template: require '../templates/first_sync'

    events: ->
        'tap #btn-end': 'end'

    getRenderData: () ->
        step = app.replicator.get 'initialReplicationStep'
        console.log "onChange : #{step}"

        if step is LAST_STEP
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
        @render() is step is LAST_STEP

    end: ->
        step = parseInt(app.replicator.get('initialReplicationStep'))
        console.log "end #{step}"
        return if step isnt LAST_STEP

        app.isFirstRun = false

        app.regularStart()
