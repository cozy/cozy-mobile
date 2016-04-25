BaseView = require '../lib/base_view'
logSender = require '../lib/log_sender'

log = require('../lib/persistent_log')
    prefix: "FirstSyncView"
    date: true

module.exports = class FirstSyncView extends BaseView

    btnBackEnabled: false
    className: 'list'
    template: require '../templates/first_sync'


    getRenderData: ->
        logButton: @showLogButton or false


    events: ->
        'tap #send-log': -> logSender.send()
        'tap #btn-end' : 'end'


    initialize: ->
        # Hide layout message bar
        app.layout.hideInitMessage()
        app.layout.stopListening app.init, 'display'
        app.layout.stopListening app.init, 'error'

        # Put it back as living this page.
        @listenTo app.init, 'transition', (leaveState, enterState) ->
            if enterState is 'aLoadFilePage'
                app.layout.listenTo app.init, 'display'
                , app.layout.showInitMessage


        @listenTo app.init, 'display', @onChange
        @listenTo app.init, 'error', @displayLogButton


    onChange: (message) ->
        @$('#finishSync .progress').text t message


    displayLogButton: ->
        @showLogButton = true
        @setState 'showLogButton', @showLogButton


    onBackButtonClicked: (event) ->
        if window.confirm t "confirm exit message"
            navigator.app.exitApp()
