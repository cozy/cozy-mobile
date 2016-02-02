BaseView = require '../lib/base_view'

log = require('../lib/persistent_log')
    prefix: "FirstSyncView"
    date: true

module.exports = class FirstSyncView extends BaseView

    className: 'list'
    template: require '../templates/first_sync'

    events: ->
        'tap #btn-end': 'end'

    steps: [
        'fFirstSyncView' # 0
        'fInitialFilesReplication' # 1
        'fInitContacts' # 2
        'fInitCalendars' # 3
        'fUpdateIndex' # 4
        ]

    initialize: ->
        @listenTo app.init, 'transition', @onChange

    onChange: (leaveState, enterState) ->
        step = @steps.indexOf enterState
        if step isnt -1
            @$('#finishSync .progress').text t "message step #{step}"
