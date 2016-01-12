BaseView = require '../lib/base_view'

LAST_STEP = 5

log = require('../lib/persistent_log')
    prefix: "FirstSyncView"
    date: true

module.exports = class FirstSyncView extends BaseView

    className: 'list'
    template: require '../templates/first_sync'

    events: ->
        'tap #btn-end': 'end'

    getRenderData: () ->
        step = app.replicator.get 'initialReplicationStep'
        log.info "onChange : #{step}"

        if step is LAST_STEP
            messageText = t 'ready message'
            buttonText = t 'end'
        else
            messageText = t "message step #{step}"
            buttonText = t 'waiting...'

        return {messageText, buttonText}

    initialize: ->
        @listenTo app.replicator, 'change:initialReplicationStep', @onChange
        log.info 'starting first replication'
        app.replicator.initialReplication (err) ->
            if err
                log.error err
                alert t err.message
                setImmediate ->
                    app.router.navigate 'config', trigger: true

    onChange: (replicator) ->
        step = replicator.get 'initialReplicationStep'
        @$('#finishSync .progress').text t "message step #{step}"
        if step is LAST_STEP
            @render()
            app.init.trigger 'calendarsInited'


    end: ->
        step = parseInt(app.replicator.get('initialReplicationStep'))
        log.info "end #{step}"
        return if step isnt LAST_STEP
