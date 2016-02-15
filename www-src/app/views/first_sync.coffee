BaseView = require '../lib/base_view'

log = require('../lib/persistent_log')
    prefix: "FirstSyncView"
    date: true

module.exports = class FirstSyncView extends BaseView

    className: 'list'
    template: require '../templates/first_sync'

    events: ->
        'tap #btn-end': 'end'

    initialize: ->
        # Hide layout message bar
        app.layout.hideInitMessage()
        app.layout.stopListening app.init, 'display'

        # Put it back as living this page.
        @listenTo app.init, 'transition', (leaveState, enterState) ->
            if enterState is 'aLoadFilePage'
                app.layout.listenTo app.init, 'display'
                , app.layout.showInitMessage


        @listenTo app.init, 'display', @onChange


    onChange: (message) ->
        @$('#finishSync .progress').text t message
