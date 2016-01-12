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

        @listenTo @, 'all', () -> console.log arguments
        # TOOD / later, when config is available : @initializeMigration()


    initMigration: ->
        oldVersion = app.replicator.config.get 'appVersion'
        @migrationStates = {}
        for version, migration of @migrations
            if compareVersions(version, oldVersion) <= 0
                break
            for state in migration.states
                @migrationStates[state] = true

        @trigger 'migrationInited'


    states:
        # # First start states
        setDeviceLocale: enter: ['setDeviceLocale']

        initFileSystem: enter: ['initFileSystem']

        initDatabase: enter: ['initDatabase']

        # migrateDatabase: # done in initDatabase

        initConfig: enter: ['initConfig']


        # Post config initialized.
#        postConfigInit
        prepareToStart: enter: ['postConfigInit', 'quitSplashScreen']
        # initDeviceStatus:
        # initApplicationComponents # notifications et servicemanager

        quitSplashScreen: enter: ['quitSplashScreen']
        normalQuitSplashScreen: enter: ['quitSplashScreen']
        normalPostConfigInit: enter: ['postConfigInit']
        updatePostConfigInit: enter: ['postConfigInit']


        loadFilePage: enter: ['setListeners', 'loadFilePage']
        backup: enter: ['backup']


        # Migration states
        initMigration: enter: ['initMigration']
        updateLocalDesignDocuments: enter: ['upsertLocalDesignDocuments']
        checkPlatformVersions:
            enter: ['checkPlatformVersions']
        updatePermissions: enter: ['getPermissions']
        updateConfig: enter: ['config']

        updateRemoteRequest:
            enter: ['putRemoteRequest']
        updateVersion:
            enter: ['updateVersion']
        quitSplashScreenUpdate: enter: ['quitSplashScreen']


        # First start

        login: enter: ['login']

        initPermissions: enter: ['getPermissions']

        setDeviceName: enter: ['setDeviceName']
        initCheckPlatformVersion: enter: ['checkPlatformVersions']

        getCozyLocale: enter: ['updateCozyLocale']

        firstConfig: enter: ['config']
        insertLocalDesignDocuments: enter: ['upsertLocalDesignDocuments']
        postConfigInit: enter: ['postConfigInit']


        insertRemoteRequests: enter: ['putRemoteRequest']

        setVersion: enter: ['updateVersion']

        firstSync: enter: ['firstSync']
        # initFilesReplication: enter: ['initFilesReplication']

        # initContacts: enter: ['initContacts']
        # initCalendars: enter: ['initCalendars']

        # Service state
        # initServiceDeviceLocale # <-- OSEF ?

        # initServiceConfig:
        # backup
        # launchApp
        # quitService


    transitions:
        # Help :
        # initial_state: event: end_state

        'init': 'startApplication': 'setDeviceLocale'
        'setDeviceLocale': 'deviceLocaleSetted': 'initFileSystem'
        'initFileSystem': 'fileSystemReady': 'initDatabase'
        'initDatabase': 'databaseReady': 'initConfig'


        'initConfig':
            'configured': 'prepareToStart' # Normal start
            'newVersion': 'initMigration' # Migration
            'notConfigured': 'quitSplashScreen' # First start

        'normalPostConfigInit': 'initsDone': 'normalQuitSplashScreen'
        'normalQuitSplashScreen': 'viewInitialized': 'loadFilePage'
        'loadFilePage': 'onFilePage': 'backup'

        # Migration
        'initMigration': 'migrationInited': 'updateLocalDesignDocuments'
        'updateLocalDesignDocuments': 'localDesignUpToDate': 'checkPlatformVersions'
        'checkPlatformVersions': 'validPlatformVersions': 'quitSplashScreenUpdate'
        'quitSplashScreenUpdate': 'viewInitialized': 'updatePermissions'
        'updatePermissions': 'getPermissions': 'updateConfig'
        'updateConfig': 'configDone': 'updateRemoteRequest'
        'updateRemoteRequest': 'putRemoteRequest': 'updateVersion'
        'updateVersion': 'versionUpToDate': 'updatePostConfigInit'
        'updatePostConfigInit': 'initsDone': 'loadFilePage' # Regular start.

        # First start
        'quitSplashScreen': 'viewInitialized': 'login'
        'login': 'validCredentials': 'initPermissions'
        'initPermissions': 'getPermissions': 'setDeviceName'
        # TODO stub
        'setDeviceName': 'deviceCreated': 'firstConfig'
        # 'setDeviceName': 'deviceCreated': 'initCheckPlatformVersion'
        # 'initCheckPlatformVersion': 'validPlatformVersions': 'getCozyLocale'
        #'getCozyLocale': 'cozyLocaleUpToDate': 'config'
        'firstConfig': 'configDone': 'insertLocalDesignDocuments'
        'insertLocalDesignDocuments': 'localDesignUpToDate': 'postConfigInit'
        'postConfigInit': 'initsDone': 'setVersion'
        'setVersion': 'versionUpToDate': 'firstSync'
        # TODO stub
        #'config': 'configUpToDate': 'insertLocalDesignDocument'
        #'insertLocalDesignDocument': 'localDesignUpToDate': 'insertRemoteRequests'
        #'insertRemoteRequests': 'putRemoteRequest': 'setVersion'
        #'setVersion': 'versionUpToDate': 'initFilesReplication'
        #'initFilesReplication': 'filesReplicationInited': 'initContacts'
        #'initContacts': 'contactsInited': 'initCalendars'
        #'initCalendars': 'calendarsInited': 'postConfigInit' # Regular start.

        'firstSync': 'calendarsInited': 'loadFilePage'


    # Enter state methods.
    setDeviceLocale: ->
        app.setDeviceLocale @getCallbackTriggerOrQuit 'deviceLocaleSetted'

    initFileSystem: ->
        app.replicator.initFileSystem \
            @getCallbackTriggerOrQuit 'fileSystemReady'

    initDatabase: ->
        app.replicator.initDB  @getCallbackTriggerOrQuit 'databaseReady'

    initConfig: ->
        app.replicator.initConfig (err, config) =>
            console.log 'toto'
            return @exitApp err if err
            if config.remote
                if config.isNewVersion()
                    console.log 'toto3'

                    @trigger 'newVersion'
                else
                    console.log 'toto4'

                    # TODO : check first-replication is OK !
                    @trigger 'configured'
            else
                console.log 'toto2'

                @trigger 'notConfigured'

    # Normal start
    postConfigInit: ->
        console.log 'toto5'
        app.postConfigInit @getCallbackTriggerOrQuit 'initsDone'

    backup: ->
        app.replicator.backup {}, (err) -> log.error err if err
        @trigger 'backupStarted'

    quitSplashScreen: ->
        app.layout.quitSplashScreen()
        Backbone.history.start()
        @trigger 'viewInitialized'

    setListeners: ->
        app.setListeners()

    loadFilePage: ->
        app.router.navigate 'folder/', trigger: true
        app.router.once 'collectionfetched', => @trigger 'onFilePage'


    # Migration
    upsertLocalDesignDocuments: ->
        return if @passUnlessInMigration 'updateLocalDesignDocuments', 'localDesignUpToDate'

        app.replicator.upsertLocalDesignDocuments @getCallbackTriggerOrQuit 'localDesignUpToDate'

    checkPlatformVersions: ->
        return if @passUnlessInMigration 'checkPlatformVersions', 'validPlatformVersions'
        app.replicator.checkPlatformVersions \
            @getCallbackTriggerOrQuit 'validPlatformVersions'

    getPermissions: ->
        return if @passUnlessInMigration 'updatePermissions', 'getPermissions'
        if app.replicator.config.hasPermissions()
            @trigger 'getPermissions'
        else
            app.router.navigate 'permissions', trigger: true


    updateConfig: ->
        return if @passUnlessInMigration 'updateConfig', 'configUpdated'
        app.router.navigate 'config', trigger: true


    putRemoteRequest: ->
        return if @passUnlessInMigration 'updateRemoteRequest', 'putRemoteRequest'

        app.replicator.putRequests @getCallbackTriggerOrQuit 'putRemoteRequest'

    updateVersion: ->
        return if @passUnlessInMigration 'updateVersion', 'versionUpToDate'

        app.replicator.config.updateVersion \
        @getCallbackTriggerOrQuit 'versionUpToDate'


    # First start
    login: ->
        console.log 'toto12'
        app.router.navigate 'login', trigger: true

    #initPermissions: -> app.router.navigate 'permissions', trigger: true

    setDeviceName: -> app.router.navigate 'device-name-picker', trigger: true

    config: ->
        return if @passUnlessInMigration 'updateConfig', 'configDone'
        app.router.navigate 'config', trigger: true

    updateCozyLocale: -> app.replicator.updateLocaleFromCozy \
        @getCallbackTriggerOrQuit 'cozyLocaleUpToDate'

    firstSync: ->
        app.router.navigate 'first-sync', trigger: true

    initFilesReplication: ->
        app.replicator.initialReplication @getCallbackTriggerOrQuit 'calendarsInited'


#ready: -> app.regularStart @getCallbackTriggerOrQuit 'inited'
    # Tools

    getCallbackTriggerOrQuit: (eventName) ->
        (err) =>
            if err
                @exitApp err
            else
                @trigger eventName

    exitApp: (err) ->
        log.error err
        msg = err.message or err
        msg += "\n #{t('error try restart')}"
        alert msg
        navigator.app.exitApp()

    passUnlessInMigration: (state, event) ->
        if state is @currentState and state not of @migrationStates
            log.info "Skip state #{state} during migration so fire #{event}."
            @trigger event
            return true


    # Migrations

    migrations:
        '0.1.18': states: ['updatePermissions', 'updateRemoteRequest']
        '0.1.17':
            states: ['checkPlatformVersions', 'updatePermissions',
                'updateRemoteRequest']


