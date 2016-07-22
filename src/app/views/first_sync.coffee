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
        message: @message


    events: ->
        'tap #send-log': -> logSender.send()
        'tap #btn-restart' : =>
            @hideLogButton()
            app.init.trigger 'restart'
        'tap #btn-end' : 'end'


    initialize: ->
        app.layout.hideInitMessage()
        @message = 'message step 0'
        # Hide layout message bar
        app.layout.stopListening app.init, 'display'
        app.layout.stopListening app.init, 'error'

        @listenTo app.init, 'display', @onChange
        @listenTo app.init, 'error', @displayLogButton

        @displayField = @$('#finishSync .progress')


    onChange: (message) ->
        @message = message
        @$('#finishSync .progress').text t message


    changeCounter: (state, total, msg = '') ->
        unless msg is ''
            msg = t(msg) + '<br>'
        if state is total
            @$('#finishSync .counter').text ''
        else
            @$('#finishSync .counter').html "#{msg}(#{state}/#{total})"


    displayLogButton: ->
        @showLogButton = true
        @setState 'showLogButton', @showLogButton


    hideLogButton: ->
        @showLogButton = false
        @setState 'showLogButton', @showLogButton


    onBackButtonClicked: (event) ->
        if window.confirm t "confirm exit message"
            navigator.app.exitApp()
