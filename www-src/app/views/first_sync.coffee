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
        else
            messageText = t 'wait message', progress: parseInt(percent * 100)
            buttonText = t 'waiting...'

        return {messageText, buttonText}

    initialize: ->
        @listenTo app.replicator, 'change:initialReplicationRunning', @onChange

    onChange: (replicator) ->
        percent = replicator.get 'initialReplicationRunning'
        percent = parseInt percent * 100
        @$('#finishSync .progress').text t 'wait message', progress: percent

        @render() if percent >= 100

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