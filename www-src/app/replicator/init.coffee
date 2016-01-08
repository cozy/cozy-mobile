compareVersions = require('../lib/compare_versions').compareVersions

log = require('../lib/persistent_log')
    date: true
    processusTag: "Init"

module.exports = class Init

    _.extend Init.prototype, Backbone.Events
    _.extend Init.prototype, Backbone.StateMachine

    # Override this function to use it as initialize.
    startStateMachine: ->
        @initialize()
        Backbone.StateMachine.startStateMachine.bind(@)(arguments)

    initialize: ->
        @listenTo @, 'transition', (leaveState, enterState) ->
            log.info 'Transition from state "'+leaveState+'" to state "'+enterState+'"'

        @initializeMigration()


    initializeMigration: (oldVersion) ->
        @initializeMigration app.replicator.config.get 'appVersion'
        @migrationStates = {}
        for version, migration of @migrations
            if compareVersions(version, oldVersion) <= 0
                break
            for state in migration.states
                @migrationStates[state] = true


    states:
        # # First start states
        # brandNew: {}
        # registered: {}

        # # service states

        # Migration states
        # outDated: {}
        checkPlatformVersions:
            enter: ['checkPlatformVersions']
        updatePermissions:
            enter: ['getPermissions']

        updateRemoteRequest:
            enter: ['putRemoteRequest']
        updateVersion:
            enter: ['updateVersion']

        # Running state.
        ready:
            enter: ['ready']

    transitions:
        # Help :
        # initial_state: event: end_state

        # # First start transitions
        # brandNew: getPermission: registered
        # registered: firstReplication: ready

        # Migration transitions
        'init': 'newVersion': 'checkPlatformVersions'
        'checkPlatformVersions': 'validPlatformVersions' : 'updatePermissions'
        'updatePermissions': 'getPermissions': 'updateRemoteRequest'
        'updateRemoteRequest': 'putRemoteRequest': 'updateVersion'
        'updateVersion': 'versionUpToDate':  'ready'

    # Migration !
    # Enter state methods.
    checkPlatformVersions: ->
        return if @passUnlessInMigration 'checkPlatformVersions', 'validPlatformVersions'
        app.replicator.checkPlatformVersions \
            @getCallbackTriggerOrQuit 'validPlatformVersions'

    getPermissions: ->
        return if @passUnlessInMigration 'updatePermissions', 'getPermissions'
        if config.hasPermissions()
            @trigger 'getPermissions'
        else
            app.router.navigate 'permissions', trigger: true

    putRemoteRequest: ->
        return if @passUnlessInMigration 'updateRemoteRequest', 'putRemoteRequest'

        app.replicator.putRequests @getCallbackTriggerOrQuit 'putRemoteRequest'

    updateVersion: ->
        return if @passUnlessInMigration 'updateVersion', 'versionUpToDate'

        app.replicator.config.updateVersion \
        @getCallbackTriggerOrQuit 'versionUpToDate'

    ready: -> app.regularStart @getCallbackTriggerOrQuit 'inited'

    # Tools

    getCallbackTriggerOrQuit: (eventName) ->
        (err) =>
            if err
                log.error err
                msg = err.message or err
                msg += "\n #{t('error try restart')}"
                alert msg
                navigator.app.exitApp()
            else
                @trigger eventName

    passUnlessInMigration: (state, event) ->
        unless state of @migrationStates
            log.info "Skip state #{state} during migration so fire #{event}."
            @trigger event
            return true


    # Migrations

    migrations:
        '0.1.18': states: ['updatePermissions', 'updateRemoteRequest']
        '0.1.17':
            states: ['checkPlatformVersions', 'updatePermissions',
                'updateRemoteRequest']


