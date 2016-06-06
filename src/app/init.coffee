async = require 'async'
AndroidAccount = require './replicator/fromDevice/android_account'
ChangeDispatcher = require './replicator/change/change_dispatcher'
ChangesImporter = require './replicator/fromDevice/changes_importer'
CheckPlatformVersions = require './migrations/check_platform_versions'
Config = require './lib/config'
Database = require './lib/database'
DesignDocuments = require './replicator/design_documents'
DeviceStatus   = require './lib/device_status'
FilterManager = require './replicator/filter_manager'
FileCacheHandler = require './lib/file_cache_handler'
PutRemoteRequest = require('./migrations/put_remote_request')
Replicator = require './replicator/main'
RequestCozy = require './lib/request_cozy'
ServiceManager = require './models/service_manager'
Translation = require './lib/translation'
ConnectionHandler = require './lib/connection_handler'
toast = require './lib/toast'

log = require('./lib/persistent_log')
    prefix: "Init"
    date: true


###*
 * Conductor of the init process.
 * It handle first start, normal start, service and config changes.
 * It organize an explicit the different steps (such as put filters in remote
 * cozy, copy view to init a replication on a doctype, ...).
 *
 * It structured as a finite state machine and event, trough this lib:
 * https://github.com/sebpiq/backbone.statemachine
###
module.exports = class Init

    _.extend Init.prototype, Backbone.Events
    _.extend Init.prototype, Backbone.StateMachine

    constructor: (@app) ->
        log.debug "constructor"

        @connection = new ConnectionHandler()
        @translation = new Translation()
        @database = new Database()
        @config = new Config @database
        @replicator = new Replicator()
        @requestCozy = new RequestCozy @config
        @fileCacheHandler = new FileCacheHandler @database.localDb, \
                @database.replicateDb, @requestCozy

        @listenTo @, 'transition', (leaveState, enterState) =>

            log.info "Transition from state #{leaveState} \
                      to state #{enterState}"

            if @states[enterState]?.display?
                @trigger 'display', @states[enterState].display

            # Hide display if no needed in comming state.
            else if @states[leaveState]?.display?
                @trigger 'noDisplay'

        return @


    initConfig: (callback) ->
        @fileCacheHandler.load =>
            @replicator.initConfig @config, @requestCozy, @database, \
                    @fileCacheHandler
            callback()


    # Override this function to use it as initialize.
    startStateMachine: ->
        log.debug "startStateMachine"

        Backbone.StateMachine.startStateMachine.apply @


    # activating contact or calendar sync requires to init them,
    # trough init state machine
    # @param needSync {calendars: true, contacts: false } type object, if
    # it should be updated or not.
    updateConfig: (needInit) ->
        log.debug 'updateConfig'
        # Do sync only while on Realtime : TODO: handles others Running states
        # waiting for them to end.
        if @currentState in ['nRealtime', 'cUpdateIndex', 'nImport', 'nBackup']
            db = @database.replicateDb
            filterManager = new FilterManager @config, @requestCozy, db
            filterManager.setFilter =>
                if needInit.syncCalendars and needInit.syncContacts
                    @toState 'c3RemoteRequest'
                else if needInit.syncContacts
                    @toState 'c1RemoteRequest'
                else if needInit.syncCalendars
                    @toState 'c2RemoteRequest'
                else
                    @toState 'c4RemoteRequest'
        else
            @app.router.forceRefresh()
            @trigger 'error', new Error 'App is busy'


    launchBackup: ->
        log.debug 'backup'

        if @currentState is 'nRealtime'
            @stopRealtime()
            @toState 'nImport'

        else
            @trigger 'error', new Error 'App is busy'


    states:
        # States naming convention :
        # - a : application start.
        # - n : normal start
        # - f : first start
        # - s : service start
        # - c : update config states

        exit: enter: ['exit']

        ########################################
        # Start application
        aConfigLoad: enter: ['configLoad'], quitOnError: true
        aDeviceLocale: enter: ['setDeviceLocale'], quitOnError: true
        aInitFileSystem: enter: ['initFileSystem'], quitOnError: true
        aQuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true # RUN
        aCheckState: enter: ['aCheckState'], quitOnError: true

        #######################################
        # Normal states
        nLoadFilePage: enter: ['setListeners', 'loadFilePage']
        nImport:
            enter: ['import']
            display: 'syncing' # TODO: more accurate translate key
        nBackup: enter: ['backup']
        nRealtime: enter: ['startRealtime']

        #######################################
        # First start (f) states
        fWizardWelcome  : enter: ['loginWizard']
        fWizardURL      : enter: ['loginWizard']
        fWizardPassword : enter: ['loginWizard']
        fWizardFiles    : enter: ['permissionsWizard']
        fWizardContacts : enter: ['permissionsWizard']
        fWizardPhotos   : enter: ['permissionsWizard']
        fWizardCalendars : enter: ['permissionsWizard']
        fCreateDevice: enter: ['createDevice']
        fCheckPlatformVersion: enter: ['checkPlatformVersions']
        fConfig: enter: ['config']
        fFirstSyncView:
            enter: ['firstSyncView'] # RUN
            display: 'message step 0' # TODO: more accurate translate key
        fLocalDesignDocuments:
            enter: ['upsertLocalDesignDocuments']
            display: 'message step 0' # TODO: more accurate translate key
        fRemoteRequest:
            enter: ['putRemoteRequest']
            display: 'message step 0' # TODO: more accurate translate key

        fTakeDBCheckpoint:
            enter: ['takeDBCheckpoint']
            display: 'message step 0' # TODO: more accurate translate key
        fInitFiles:
            enter: ['initFiles']
            display: 'message step 0' # TODO: more accurate translate key
        fInitFolders:
            enter: ['initFolders']
            display: 'message step 1' # TODO: more accurate translate key
        fCreateAccount:
            enter: ['createAndroidAccount']
            display: 'message step 3' # TODO: more accurate translate key
        fInitContacts:
            enter: ['initContacts']
            display: 'message step 3' # TODO: more accurate translate key
        fInitCalendars:
            enter: ['initCalendars']
            display: 'message step 4' # TODO: more accurate translate key
        fSync:
            enter: ['postCopyViewSync']
            display: 'message step 5' # TODO: more accurate translate key
        fUpdateIndex:
            enter: ['updateIndex']
            display: 'message step 5' # TODO: more accurate translate key

        ###################
        # First start error steps
        # 1 error before FirstSync End. --> Go to config.
        f1QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true

        # 2 error after File sync
        f2QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true
        f2FirstSyncView: enter: ['firstSyncView'] # RUN

        # 3 error after contacts sync
        f3QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true
        f3FirstSyncView: enter: ['firstSyncView'] # RUN

        # 4 error after calendars sync
        f4QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true
        f4FirstSyncView: enter: ['firstSyncView'] # RUN


        # Last commons steps
        aResume: enter: ['onResume']
        aPause: enter: ['onPause']
        aViewingFile: enter: ['onPause']

        #######################################
        # Service
        sCheckState: enter: ['sCheckState'], quitOnError: true
        sConfigLoad: enter: ['configLoad'], quitOnError: true
        sDeviceLocale: enter: ['setDeviceLocale'], quitOnError: true
        sInitFileSystem: enter: ['initFileSystem'], quitOnError: true

        sImport: enter: ['import'], quitOnError: true
        sSync: enter: ['sSync'], quitOnError: true
        sBackup: enter: ['backup'], quitOnError: true
        sSync2: enter: ['sSync'], quitOnError: true

        #######################################
        # Config update states (c)
        # activate sync-contacts (c1)
        c1RemoteRequest: enter: ['stopRealtime', 'putRemoteRequest']
        c1TakeDBCheckpoint:
            enter: ['takeDBCheckpoint']
            display: 'contacts_sync'
        c1CreateAccount:
            enter: ['createAndroidAccount']
            display: 'contacts_sync'
        c1InitContacts:
            enter: ['initContacts']
            display: 'contacts_sync'

        # activate sync-calendars (c2)
        c2RemoteRequest: enter: ['stopRealtime', 'putRemoteRequest']
        c2TakeDBCheckpoint:
            enter: ['takeDBCheckpoint']
            display: 'calendar_sync'
        c2CreateAccount:
            enter: ['createAndroidAccount']
            display: 'calendar_sync'
        c2InitCalendars:
            enter: ['initCalendars']
            display: 'calendar_sync'

        # activate sync acontacts and sync calendars
        c3RemoteRequest: enter: ['stopRealtime', 'putRemoteRequest']
        c3TakeDBCheckpoint:
            enter: ['takeDBCheckpoint']
            display: 'contacts_sync'
        c3CreateAccount:
            enter: ['createAndroidAccount']
            display: 'contacts_sync'
        c3InitContacts:
            enter: ['initContacts']
            display: 'contacts_sync'
        c3InitCalendars:
            enter: ['initCalendars']
            display: 'calendar_sync'

        # update filters
        c4RemoteRequest: enter: ['stopRealtime', 'putRemoteRequest']

        # Commons update states.
        cSync:
            enter: ['postCopyViewSync']
            display: 'setup end'
        cUpdateIndex:
            enter: ['updateIndex']
            display: 'setup end'


    transitions:
        # Help :
        # initial_state: event: end_state

        'init':
            'startApplication': 'aDeviceLocale'
            'startService': 'sConfigLoad'

        ########################################
        # Start application
        'aDeviceLocale': 'deviceLocaleSetted': 'aConfigLoad'
        'aConfigLoad': 'loaded': 'aInitFileSystem'
        'aInitFileSystem': 'fileSystemReady': 'aQuitSplashScreen'
        'aQuitSplashScreen': 'viewInitialized': 'aCheckState'
        'aCheckState':
            'default': 'fWizardWelcome'
            'deviceCreated': 'fWizardFiles'
            'appConfigured': 'fFirstSyncView'
            'syncCompleted': 'nLoadFilePage'

        #######################################
        # Start Service
        'sConfigLoad': 'loaded': 'sCheckState'
        'sCheckState':
            'exit': 'exit'
            'continue': 'sDeviceLocale'
        'sDeviceLocale': 'deviceLocaleSetted': 'sInitFileSystem'
        'sInitFileSystem': 'fileSystemReady': 'sImport'
        'sImport': 'importDone': 'sSync'
        'sSync': 'syncDone': 'sBackup'
        'sBackup': 'backupDone': 'sSync2'
        'sSync2': 'syncDone': 'exit'

        #######################################
        # Normal states
        'nLoadFilePage': 'onFilePage': 'nImport'
        'nImport': 'importDone': 'nBackup'
        'nBackup':
            'backupDone': 'nRealtime'
            'errorViewed': 'nRealtime'
        'nRealtime':
            'pause': 'aPause'
            'openFile': 'aViewingFile'

        #######################################
        # Running
        'aPause': 'resume': 'aResume'
        'aResume':
            'pause': 'aPause'
            'ready': 'nImport'
        'aViewingFile': 'resume': 'nRealtime'

        #######################################
        # First start
        'fWizardWelcome':
            'clickBack': 'exit'
            'clickNext': 'fWizardURL'
        'fWizardURL':
            'clickBack': 'fWizardWelcome'
            'clickNext': 'fWizardPassword'
        'fWizardPassword':
            'clickBack': 'fWizardURL'
            'validCredentials': 'fCreateDevice'
        'fCreateDevice':
            'deviceCreated': 'fWizardFiles'
            'errorViewed': 'fConfig'
        'fWizardFiles':
            'clickNext': 'fWizardContacts'
        'fWizardContacts':
            'clickBack': 'fWizardFiles'
            'clickNext': 'fWizardCalendars'
        'fWizardCalendars':
            'clickBack': 'fWizardContacts'
            'clickNext': 'fWizardPhotos'
        'fWizardPhotos':
            'clickBack': 'fWizardCalendars'
            'clickNext': 'fFirstSyncView'
        'fFirstSyncView':
            'restart': 'fFirstSyncView'
            'firstSyncViewDisplayed': 'fCheckPlatformVersion'
        'fCheckPlatformVersion':
            'restart': 'fCheckPlatformVersion'
            'validPlatformVersions': 'fLocalDesignDocuments'
            'errorViewed': 'fConfig'
        'fLocalDesignDocuments':
            'localDesignUpToDate': 'fRemoteRequest'
            'errorViewed': 'fConfig'
        'fRemoteRequest':
            'restart': 'fRemoteRequest'
            'putRemoteRequest':'fTakeDBCheckpoint'
            'errorViewed': 'fConfig'
        'fTakeDBCheckpoint':
            'restart': 'fTakeDBCheckpoint'
            'checkPointed': 'fInitFiles'
            'errorViewed': 'fConfig'
        'fInitFiles':
            'restart': 'fInitFiles'
            'filesInited': 'fInitFolders'
            'errorViewed': 'fInitFiles'
        'fInitFolders':
            'restart': 'fInitFolders'
            'foldersInited': 'fCreateAccount'
            'errorViewed': 'fInitFolders'
        'fCreateAccount':
            'restart': 'fCreateAccount'
            'androidAccountCreated': 'fInitContacts'
            'errorViewed': 'fCreateAccount'
        'fInitContacts':
            'restart': 'fInitContacts'
            'contactsInited': 'fInitCalendars'
            'errorViewed': 'fInitContacts'
        'fInitCalendars':
            'restart': 'fInitCalendars'
            'calendarsInited': 'fSync'
            'errorViewed': 'fInitCalendars'
        'fSync':
            'restart': 'fSync'
            'dbSynced': 'fUpdateIndex'
            'errorViewed': 'fSync'
        'fUpdateIndex':
            'indexUpdated': 'nLoadFilePage'
            'errorViewed': 'nLoadFilePage'


        # First start error transitions
        # 1 error after before FirstSync End. --> Go to config.
        'f1QuitSplashScreen': 'viewInitialized': 'fCheckPlatformVersion'

        # 2 error after File sync
        'f2QuitSplashScreen': 'viewInitialized': 'f2FirstSyncView'
        'f2FirstSyncView': 'firstSyncViewDisplayed': 'fInitContacts'

        # 3 error after Contacts sync
        'f3QuitSplashScreen': 'viewInitialized': 'f3FirstSyncView'
        'f3FirstSyncView': 'firstSyncViewDisplayed': 'fInitCalendars'

        # 4 error after Calendars sync
        'f4QuitSplashScreen': 'viewInitialized': 'f4FirstSyncView'
        'f4FirstSyncView': 'firstSyncViewDisplayed': 'fUpdateIndex'

        #######################################
        # Config update
        ###################
        'c1RemoteRequest':
            'putRemoteRequest': 'c1TakeDBCheckpoint'
            'errorViewed': 'nRealtime'
        'c1TakeDBCheckpoint':
            'checkPointed': 'c1CreateAccount'
            'errorViewed': 'nRealtime'
        'c1CreateAccount':
            'androidAccountCreated': 'c1InitContacts'
            'errorViewed': 'nRealtime'
        'c1InitContacts':
            'contactsInited': 'cSync'
            'errorViewed': 'nRealtime'


        ###################
        'c2RemoteRequest':
            'putRemoteRequest': 'c2TakeDBCheckpoint'
            'errorViewed': 'nRealtime'
        'c2TakeDBCheckpoint':
            'checkPointed': 'c2CreateAccount'
            'errorViewed': 'nRealtime'
        'c2CreateAccount':
            'androidAccountCreated': 'c2InitCalendars'
            'errorViewed': 'nRealtime'
        'c2InitCalendars':
            'calendarsInited': 'cSync'
            'errorViewed': 'nRealtime'

        ###################
        'c3RemoteRequest':
            'putRemoteRequest': 'c3TakeDBCheckpoint'
            'errorViewed': 'nRealtime'
        'c3TakeDBCheckpoint':
            'checkPointed': 'c3CreateAccount'
            'errorViewed': 'nRealtime'
        'c3CreateAccount':
            'androidAccountCreated': 'c3InitContacts'
            'errorViewed': 'nRealtime'
        'c3InitContacts':
            'contactsInited': 'c3InitCalendars'
            'errorViewed': 'nRealtime'
        'c3InitCalendars':
            'calendarsInited': 'cSync'
            'errorViewed': 'nRealtime'

        ###################
        'c4RemoteRequest':
            'putRemoteRequest': 'cUpdateIndex'
            'errorViewed': 'nRealtime'

        ###################
        'cSync':
            'dbSynced': 'cUpdateIndex'
            'errorViewed': 'nRealtime'
        'cUpdateIndex':
            'indexUpdated': 'nImport' #TODO : clean update headers
            'errorViewed': 'nRealtime'


    # Enter state methods.


    aCheckState: ->
        @trigger @config.get 'state'


    sCheckState: ->
        # todo: application is already launch?
        if @config.get('state') is 'syncCompleted'
            @trigger 'continue'
        else
            @trigger 'exit'


    configLoad: ->
        @config.load =>
            state = if @app.name is 'APP' then 'launch' else 'service'
            @config.set 'appState', state, =>
                unless window.isBrowserDebugging # Patch for browser debugging
                    # The ServiceManager is a flag for the background plugin to
                    # know if it's the service or the application,
                    # see https://git.io/vVjJO
                    unless @app.name is 'SERVICE'
                        @serviceManager = new ServiceManager()
                @trigger 'loaded'


    setDeviceLocale: ->
        DeviceStatus.initialize()

        @translation.setDeviceLocale @getCallbackTrigger 'deviceLocaleSetted'


    initFileSystem: ->
        @replicator.initFileSystem @getCallbackTrigger 'fileSystemReady'


    import: ->
        changesImporter = new ChangesImporter()
        changesImporter.synchronize (err) =>
            log.error err if err
            @trigger 'importDone'


    backup: ->
        @replicator.backup {}, @getCallbackTrigger 'backupDone'


    onResume: ->
        # Don't import, backup, ... while service still running
        @serviceManager.isRunning (err, running) =>
            return log.error err if err

            # If service still running, try again later
            if running
                @timeout = setTimeout (() => @onResume()), 10 * 1000
                log.info 'Service still running, backup later'

            else
                @trigger 'ready'


    onPause: ->
        log.info "onPause"

        @stopRealtime()
        clearTimeout @timeout if @timeout


    startRealtime: ->
        @replicator.startRealtime()


    stopRealtime: ->
        @replicator.stopRealtime()


    quitSplashScreen: ->
        @app.startLayout()
        @app.layout.quitSplashScreen()
        Backbone.history.start()
        @trigger 'viewInitialized'


    setListeners: ->
        @app.setListeners()


    loadFilePage: ->
        @app.router.navigate 'folder/', trigger: true
        @app.router.once 'collectionfetched', => @trigger 'onFilePage'


    upsertLocalDesignDocuments: (callback) ->
        designDocs =
            new DesignDocuments @database.replicateDb, @database.localDb
        unless callback
            callback = ->
            @trigger 'localDesignUpToDate'
        designDocs.createOrUpdateAllDesign callback


    putRemoteRequest: ->
        PutRemoteRequest.putRequests (err) =>
            if err
                log.error err
                toast.error err
            @trigger 'putRemoteRequest'


    # First start


    loginWizard: ->
        @app.router.navigate "login/#{@currentState}", trigger: true


    permissionsWizard: ->
        @app.router.navigate "permissions/#{@currentState}", trigger: true


    createDevice: ->
        url = @config.get 'cozyURL'
        password = @config.get 'devicePassword'
        deviceName = @config.get 'deviceName'

        @replicator.registerRemoteSafe url, password, deviceName, (err, body) =>
            return @handleError err if err
            @config.set 'state', 'deviceCreated'
            @config.set 'deviceName', body.login
            @config.set 'devicePassword', body.password
            @config.set 'devicePermissions', body.permissions
            @database.setRemoteDatabase @config.getCozyUrl()

            @trigger 'deviceCreated'


    config: ->
        if @currentState is 'smConfig'
            @app.startMainActivity 'smConfig'
        else
            @app.router.navigate 'config', trigger: true

    updateCozyLocale: -> @replicator.updateLocaleFromCozy \
        @getCallbackTrigger 'cozyLocaleUpToDate'

    firstSyncView: ->
        @app.router.navigate 'first-sync', trigger: true
        replicateDB = @database.replicateDb
        filterManager = new FilterManager @config, @requestCozy, replicateDB
        return @handleError 'error_connection' unless @connection.isConnected()
        filterManager.setFilter (err) =>
            return @handleError err if err
            @trigger 'firstSyncViewDisplayed'

    takeDBCheckpoint: ->
        @replicator.takeCheckpoint @getCallbackTrigger 'checkPointed'

    initFiles: ->
        @replicator.copyView docType: 'file', @getCallbackTrigger 'filesInited'

    initFolders: ->
        @replicator.copyView docType: 'folder', \
            @getCallbackTrigger 'foldersInited'

    createAndroidAccount: ->
        if @config.get('syncContacts') or \
                @config.get('syncCalendars')
            androidAccount = new AndroidAccount()
            androidAccount.create @getCallbackTrigger 'androidAccountCreated'

        else
            @trigger 'androidAccountCreated' # TODO: rename event.

    # 1. Copy view for contact
    # 2. dispatch inserted contacts to android through the change dispatcher
    initContacts: ->
        if @config.get 'syncContacts'
            changeDispatcher = new ChangeDispatcher()
            # 1. Copy view for contact
            @replicator.copyView
                docType: 'contact'
                attachments: true
            , (err, contacts) =>
                return @handleError err if err

                async.eachSeries contacts, (contact, cb) ->
                    # 2. dispatch inserted contacts to android
                    changeDispatcher.dispatch contact, cb
                , @getCallbackTrigger 'contactsInited'
        else
            @trigger 'contactsInited' # TODO rename event to 'noSyncContacts'


    # 1. Copy view for event
    # 2. dispatch inserted events to android through the change dispatcher
    initCalendars: ->
        if @config.get('syncCalendars')
            changeDispatcher = new ChangeDispatcher()
            # 1. Copy view for event
            @replicator.copyView docType: 'event', (err, events) =>
                return @handleError err if err
                async.eachSeries events, (event, cb) ->
                    # 2. dispatch inserted events to android
                    changeDispatcher.dispatch event, cb
                , @getCallbackTrigger 'calendarsInited'
        else
            @trigger 'calendarsInited' # TODO: rename event to noSyncCalendars


    postCopyViewSync: ->
        # Get the local last seq :
        @replicator.db.changes
            descending: true
            limit: 1
        , (err, changes) =>
            localCheckpoint = changes.last_seq

            @replicator.sync
                remoteCheckpoint: window.app.checkpointed
                localCheckpoint: localCheckpoint
            , (err) =>
                return @handleError err if err

                # Copy view is done. Unset this transition var.
                delete window.app.checkpointed
                @config.set 'state', 'syncCompleted'
                @trigger 'dbSynced'


    updateIndex: ->
        @replicator.updateIndex @getCallbackTrigger 'indexUpdated'


    checkPlatformVersions: ->
        CheckPlatformVersions.checkPlatformVersions (err, response) =>
            if err
                if @app.layout.currentView
                    # currentView is device-name view
                    return @handleError err
                else
                    alert err.message
                    return @app.exit()

            @trigger 'validPlatformVersions'



    ###########################################################################
    # Service
    sSync: ->
        @replicator.sync {}, @getCallbackTrigger 'syncDone'


    exit: ->
        @app.exit()


    ###########################################################################
    # Tools


    # show the error to the user appropriately regarding to the current state
    handleError: (err) ->
        log.warn err
        if @states[@currentState].quitOnError
            @app.exit err
        else
            if err is 'error_connection' or err?.cors is 'rejected'
                app.layout.showError err
            else
                @trigger 'error', err


    # Provide a callback,
    # - which appropriately regarding to the state show the error to the user
    # - or trigger event if no error
    getCallbackTrigger: (eventName) ->
        (err) =>
            if err
                @handleError err
            else
                @trigger eventName
