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

        # @listenTo @, 'all', () -> console.log arguments
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
        # First commons steps
        setDeviceLocale: enter: ['setDeviceLocale']
        initFileSystem: enter: ['initFileSystem']
        initDatabase: enter: ['initDatabase']
        # migrateDatabase: # done in initDatabase
        initConfig: enter: ['initConfig']

        # Normal (n) states
        nPostConfigInit: enter: ['postConfigInit']
        nQuitSplashScreen: enter: ['quitSplashScreen']


        # Migration (m) states
        migrationInit: enter: ['initMigration']
        mLocalDesignDocuments: enter: ['upsertLocalDesignDocuments']
        mCheckPlatformVersions: enter: ['checkPlatformVersions']
        mQuitSplashScreen: enter: ['quitSplashScreen']
        mPermissions: enter: ['getPermissions']
        mConfig: enter: ['config']
        mRemoteRequest: enter: ['putRemoteRequest']
        mUpdateVersion: enter: ['updateVersion']
        mPostConfigInit: enter: ['postConfigInit']


        # First start (f) states
        fQuitSplashScreen: enter: ['quitSplashScreen'] # RUN
        fLogin: enter: ['login']
        fPermissions: enter: ['getPermissions']
        # TODO fCheckPlatformVersion: enter: ['checkPlatformVersions']
        # todo ! getCozyLocale: enter: ['updateCozyLocale']
        fDeviceName: enter: ['setDeviceName']
        fConfig: enter: ['saveState', 'config']
        fLocalDesignDocuments: enter: ['upsertLocalDesignDocuments']
        fPostConfigInit: enter: ['postConfigInit'] # RUN
        fSetVersion: enter: ['updateVersion']
        fFirstSync: enter: ['firstSync']

        # TODO split initialReplication
        # fRemoteRequests: enter: ['putRemoteRequest']
        # fInitialFilesReplication: enter: ['initFilesReplication']
        # fInitContacts: enter: ['saveState', 'initContacts']
        # fInitCalendars: enter: ['saveState', 'initCalendars']
        #
        # # First start error steps
        # # 2 error after File sync
        # f2QuitSplashScreen: enter: ['quitSplashScreen']
        # f2PostConfigInit: enter: ['postConfigInit'] # RUN

        # # 3 error after calendars sync
        # f3QuitSplashScreen: enter: ['quitSplashScreen']
        # f3PostConfigInit: enter: ['postConfigInit'] # RUN


        # First start error steps
        # 1 error before FirstSync End. --> Go to config.
        f1QuitSplashScreen: enter: ['quitSplashScreen'] # RUN


        # Service state
        # initServiceDeviceLocale # <-- OSEF ?

        # initServiceConfig:
        # backup
        # launchApp
        # quitService



        # Last commons steps
        loadFilePage: enter: ['saveState', 'setListeners', 'loadFilePage']
        backup: enter: ['backup']


    transitions:
        # Help :
        # initial_state: event: end_state

        'init': 'startApplication': 'setDeviceLocale'
        'setDeviceLocale': 'deviceLocaleSetted': 'initFileSystem'
        'initFileSystem': 'fileSystemReady': 'initDatabase'
        'initDatabase': 'databaseReady': 'initConfig'


        'initConfig':
            'configured': 'nPostConfigInit' # Normal start
            'newVersion': 'migrationInit' # Migration
            'notConfigured': 'fQuitSplashScreen' # First start
            # First start error
            'goTofConfig': 'f1QuitSplashScreen'

        'nPostConfigInit': 'initsDone': 'nQuitSplashScreen'
        'nQuitSplashScreen': 'viewInitialized': 'loadFilePage'
        'loadFilePage': 'onFilePage': 'backup'

        # Migration
        'migrationInit': 'migrationInited': 'mLocalDesignDocuments'
        'mLocalDesignDocuments':
            'localDesignUpToDate': 'mCheckPlatformVersions'
        'mCheckPlatformVersions': 'validPlatformVersions': 'mQuitSplashScreen'
        'mQuitSplashScreen': 'viewInitialized': 'mPermissions'
        'mPermissions': 'getPermissions': 'mConfig'
        'mConfig': 'configDone': 'mRemoteRequest'
        'mRemoteRequest': 'putRemoteRequest': 'mUpdateVersion'
        'mUpdateVersion': 'versionUpToDate': 'mPostConfigInit'
        'mPostConfigInit': 'initsDone': 'loadFilePage' # Regular start.

        # First start
        'fQuitSplashScreen': 'viewInitialized': 'fLogin'
        'fLogin': 'validCredentials': 'fPermissions'
        'fPermissions': 'getPermissions': 'fDeviceName'
        # TODO stub
        'fDeviceName': 'deviceCreated': 'fConfig'
        # 'setDeviceName': 'deviceCreated': 'initCheckPlatformVersion'
        # 'initCheckPlatformVersion': 'validPlatformVersions': 'getCozyLocale'
        #'getCozyLocale': 'cozyLocaleUpToDate': 'config'
        'fConfig': 'configDone': 'fLocalDesignDocuments'
        'fLocalDesignDocuments': 'localDesignUpToDate': 'fPostConfigInit'
        'fPostConfigInit': 'initsDone': 'fSetVersion'
        'fSetVersion': 'versionUpToDate': 'fFirstSync'
        'fFirstSync': 'calendarsInited': 'loadFilePage'


        # # TODO move initialReplication in state machine.
        # 'fRemoteRequests': 'putRemoteRequest': 'fInitialFilesReplication'
        # 'fInitialFilesReplication': 'filesReplicationInited': 'fInitContacts'
        # 'fInitContacts': 'contactsInited': 'fInitCalendars'
        # 'fInitCalendars': 'calendarsInited': 'loadFilePage'

        # # First start error transitions
        # # 2 error after File sync
        # 'f2QuitSplashScreen': 'viewInitialized': 'f2PostConfigInit'
        # 'f2PostConfigInit': 'initsDone': 'fInitContacts'

        # # 3 error after Calendars sync
        # 'f3QuitSplashScreen': 'viewInitialized': 'f3PostConfigInit'
        # 'f3PostConfigInit': 'initsDone': 'fInitCalendars'

        # First start error transitions
        # 1 error after before FirstSync End. --> Go to config.
        'f1QuitSplashScreen': 'viewInitialized': 'fConfig'


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
            return @exitApp err if err
            if config.remote
                # Check last state
                # If state is "ready" -> newVersion ? newVersion : configured
                # Else : go to this state (with preconditions checks ?)
                lastState = config.get('lastInitState') or 'loadFilePage'

                # Watchdog
                if lastState not in ['loadFilePage', 'Config']
                    return @trigger 'goTofConfig'

                if lastState is 'loadFilePage' # Previously in normal start.
                    if config.isNewVersion()
                        @trigger 'newVersion'
                    else
                        @trigger 'configured'
                else # In init.
                    @trigger "goTo#{lastState}"


            else
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
        return if @passUnlessInMigration 'mLocalDesignDocuments', 'localDesignUpToDate'

        app.replicator.upsertLocalDesignDocuments @getCallbackTriggerOrQuit 'localDesignUpToDate'

    checkPlatformVersions: ->
        return if @passUnlessInMigration 'mCheckPlatformVersions', 'validPlatformVersions'
        app.replicator.checkPlatformVersions \
            @getCallbackTriggerOrQuit 'validPlatformVersions'

    getPermissions: ->
        return if @passUnlessInMigration 'mPermissions', 'getPermissions'
        if app.replicator.config.hasPermissions()
            @trigger 'getPermissions'
        else
            app.router.navigate 'permissions', trigger: true


    putRemoteRequest: ->
        return if @passUnlessInMigration 'mRemoteRequest', 'putRemoteRequest'

        app.replicator.putRequests @getCallbackTriggerOrQuit 'putRemoteRequest'

    updateVersion: ->
        app.replicator.config.updateVersion \
        @getCallbackTriggerOrQuit 'versionUpToDate'


    # First start
    login: ->
        app.router.navigate 'login', trigger: true

    #initPermissions: -> app.router.navigate 'permissions', trigger: true

    setDeviceName: -> app.router.navigate 'device-name-picker', trigger: true

    config: ->
        return if @passUnlessInMigration 'mConfig', 'configDone'
        app.router.navigate 'config', trigger: true

    updateCozyLocale: -> app.replicator.updateLocaleFromCozy \
        @getCallbackTriggerOrQuit 'cozyLocaleUpToDate'

    firstSync: ->
        app.router.navigate 'first-sync', trigger: true

    # initFilesReplication: ->
    #     app.replicator.initialReplication @getCallbackTriggerOrQuit 'calendarsInited'



#ready: -> app.regularStart @getCallbackTriggerOrQuit 'inited'
    # Tools
    saveState: ->
        app.replicator.config.save lastInitState: @currentState
        , (err, config) -> log.warn err if err

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


