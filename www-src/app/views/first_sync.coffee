BaseView = require '../lib/base_view'

module.exports = class FirstSyncView extends BaseView

    className: 'list'
    template: require '../templates/first_sync'

    events: ->
        'tap #btn-end': 'end'

    getRenderData: ->

        percent = app.replicator.get('initialReplicationRunning') or 0
        if percent and percent is 1
            messageText = t 'ready message'
            buttonText = t 'end'
        else if percent < -1
            messageText = t 'wait message device'
            buttonText = t 'waiting...'
        else if percent < 0
            messageText = t 'wait message cozy'
            buttonText = t 'waiting...'
        else if percent is 0.90
            messageText = t 'wait message display'
            buttonText = t 'waiting...'
        else
            messageText = t 'wait message', progress: 5 + parseInt(percent * 100)
            buttonText = t 'waiting...'

        return {messageText, buttonText}

    initialize: ->
        @listenTo app.replicator, 'change:initialReplicationRunning', @onChange

    onChange: (replicator) ->
        percent = replicator.get 'initialReplicationRunning'
        if percent is 0.90
            @$('#finishSync .progress').text t 'wait message display'
        else
            @$('#finishSync .progress').text t 'wait message', progress: 5 + parseInt(percent * 100)

        @render() if percent >= 1

    end: ->
        percent = parseInt(app.replicator.get('initialReplicationRunning'))
        console.log "end #{percent}"
        return if percent isnt 1

        # start the first contact & pictures backup
        app.replicator.backup (err) ->
            alert err if err
            console.log "pics & contacts synced"

        # go to home
        app.isFirstRun = false
        app.router.navigate 'folder/', trigger: true