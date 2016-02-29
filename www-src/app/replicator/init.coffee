semver = require 'semver'
async = require 'async'
ChangeDispatcher = require './change/change_dispatcher'
ChangesImporter = require './fromDevice/changes_importer'
AndroidAccount = require './fromDevice/android_account'

log = require('../lib/persistent_log')
    date: true
    processusTag: "Init"

###*
 * Conductor of the init process.
 * It handle first start, migrations, normal start, service and config changes.
 * It organize an explicit the different steps (such as put filters in remote
 * cozy, copy view to init a replication on a doctype, ...).
 *
 * It structured as a finite state machine and event, trough this lib:
 * https://github.com/sebpiq/backbone.statemachine
 *
 * **A word about migrations**
 * Migrations occurs on app upgrade, to adapt app and his environment to the
 * requireemnts of the new version. It may be updating remote CouchDB views,
 * local PouchDB views, permissions, new config, ...
 * This class handle this with dedicated states (prefixed with 'm' - or 'sm'
 * if migration can occurs from service).
 *
 * How to use it:
 * If a migration is required add to 'migrations' property, a key with the
 * version name, and as object, the liste of migrations states required by
 * this new version.
 *
 * Init take care about getting only trough the necessary migrations states,
 * for any migrations (as well as from 0.2.14 to 0.2.15 as
 * from 0.1.3 to 0.2.15) - see initMigrations, passUnlessInMigration,
 * migrations and migrationStates to see how it works.

###
module.exports = class Init

    _.extend Init.prototype, Backbone.Events
    _.extend Init.prototype, Backbone.StateMachine

    # Override this function to use it as initialize.
    startStateMachine: ->
        @initialize()
        Backbone.StateMachine.startStateMachine.apply @, arguments


    initialize: ->
        @migrationStates = {}

        @listenTo @, 'transition', (leaveState, enterState) ->
            log.info "Transition from state #{leaveState} \
                      to state #{enterState}"

        @listenTo @, 'transition', (leaveState, enterState) =>
            if @states[enterState]?.display?
                @trigger 'display', @states[enterState].display

            # Hide display if no needed in comming state.
            else if @states[leaveState]?.display?
                @trigger 'noDisplay'

    updateConfig: (needInit) ->
        log.info 'updateConfig'
        # Do sync only while on Realtime : TODO: handles others Running states
        # waiting for them to end.
        if @currentState in ['aRealtime', 'cUpdateIndex', 'aImport', 'aBackup']
            if needInit.calendars and needInit.contacts
                @toState 'c3RemoteRequest'
            else if needInit.contacts
                @toState 'c1RemoteRequest'
            else if needInit.calendars
                @toState 'c2RemoteRequest'
            #else unless _.isEmpty(needInit)

            else
                @toState 'c4RemoteRequest'
                # @trigger 'initDone'

        else if @currentState in ['fConfig', 'mConfig']
            @saveConfig()
        else
            @trigger 'error', new Error 'App is busy'


    launchBackup: ->
        log.debug 'backup'

        if @currentState is 'aRealtime'
            @stopRealtime()
            @toState 'aImport'

        else
            @trigger 'error', new Error 'App is busy'


    states:
        # States naming convention :
        # - a : application start.
        # - n : normal start
        # - f : first start
        # - s : service start
        # - c : update config states
        # - m : migration start
        # - sm : migration in service start

        # Application

        # First commons steps
        aDeviceLocale: enter: ['setDeviceLocale'], quitOnError: true
        aInitFileSystem: enter: ['initFileSystem'], quitOnError: true
        aInitDatabase: enter: ['initDatabase'], quitOnError: true
        aInitConfig: enter: ['initConfig'], quitOnError: true

        #######################################
        # Normal (n) states
        nPostConfigInit: enter: ['postConfigInit'], quitOnError: true
        nQuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true

        #######################################
        # First start (f) states
        fQuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true # RUN
        fLogin: enter: ['login']
        fPermissions: enter: ['getPermissions']
        fDeviceName: enter: ['setDeviceName'], leave: ['saveState']
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
        fPostConfigInit:
            enter: ['postConfigInit'] # RUN
            display: 'message step 0' # TODO: more accurate translate key
        fSetVersion:
            enter: ['updateVersion']
            display: 'message step 0' # TODO: more accurate translate key

        fTakeDBCheckpoint:
            enter: ['takeDBCheckpoint']
            display: 'message step 0' # TODO: more accurate translate key
        fInitFiles:
            enter: ['initFiles']
            display: 'message step 0' # TODO: more accurate translate key
        fInitFolders:
            enter: ['saveState', 'initFolders']
            display: 'message step 1' # TODO: more accurate translate key
        fCreateAccount:
            enter: ['createAndroidAccount']
            display: 'message step 3' # TODO: more accurate translate key
        fInitContacts:
            enter: ['saveState', 'initContacts']
            display: 'message step 3' # TODO: more accurate translate key
        fInitCalendars:
            enter: ['saveState', 'initCalendars']
            display: 'message step 4' # TODO: more accurate translate key
        fSync:
            enter: ['postCopyViewSync']
            display: 'message step 5' # TODO: more accurate translate key
        fUpdateIndex:
            enter: ['saveState', 'updateIndex']
            display: 'message step 5' # TODO: more accurate translate key

        ###################
        # First start error steps
        # 1 error before FirstSync End. --> Go to config.
        f1QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true

        # 2 error after File sync
        f2QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true
        f2FirstSyncView: enter: ['firstSyncView'] # RUN
        f2PostConfigInit: enter: ['postConfigInit'] # RUN

        # 3 error after contacts sync
        f3QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true
        f3FirstSyncView: enter: ['firstSyncView'] # RUN
        f3PostConfigInit: enter: ['postConfigInit'] # RUN

        # 4 error after calendars sync
        f4QuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true
        f4FirstSyncView: enter: ['firstSyncView'] # RUN
        f4PostConfigInit: enter: ['postConfigInit'] # RUN


        # Last commons steps
        aLoadFilePage: enter: ['saveState', 'setListeners', 'loadFilePage']
        aImport:
            enter: ['import']
            display: 'syncing' # TODO: more accurate translate key
        aBackup: enter: ['backup']
        aRealtime: enter: ['startRealtime']
        aResume: enter: ['onResume']
        aPause: enter: ['onPause']
        aViewingFile: enter: ['onPause']

        #######################################
        # Service
        sDeviceLocale: enter: ['setDeviceLocale'], quitOnError: true
        sInitFileSystem: enter: ['initFileSystem'], quitOnError: true
        sInitDatabase: enter: ['initDatabase'], quitOnError: true
        sInitConfig: enter: ['sInitConfig'], quitOnError: true

        sPostConfigInit: enter: ['postConfigInit'], quitOnError: true
        sImport: enter: ['import'], quitOnError: true
        sSync: enter: ['sSync'], quitOnError: true
        sBackup: enter: ['sBackup'], quitOnError: true
        sSync2: enter: ['sSync'], quitOnError: true
        sQuit: enter: ['sQuit'], quitOnError: true

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
        cSaveConfig:
            enter: ['saveConfig']
            display: 'setup end'
        cUpdateIndex:
            enter: ['updateIndex']
            display: 'setup end'

        #######################################
        # Migration (m) states
        migrationInit: enter: ['initMigrationState'], quitOnError: true
        mMoveCache: enter: ['migrationMoveCache']
        mLocalDesignDocuments:
            enter: ['upsertLocalDesignDocuments']
            quitOnError: true
        mCheckPlatformVersions:
            enter: ['checkPlatformVersions']
            quitOnError: true
        mQuitSplashScreen: enter: ['quitSplashScreen']
        mPermissions: enter: ['getPermissions']
        mConfig: enter: ['config']
        mRemoteRequest: enter: ['putRemoteRequest']
        mUpdateVersion: enter: ['updateVersion']
        mPostConfigInit: enter: ['postConfigInit']
        mSync: enter: ['postCopyViewSync']

        ###################
        # Service Migration (m) states
        smMigrationInit: enter: ['initMigrationState'], quitOnError: true
        smMoveCache: enter: ['migrationMoveCache'], quitOnError: true
        smLocalDesignDocuments:
            enter: ['upsertLocalDesignDocuments']
            quitOnError: true
        smCheckPlatformVersions:
            enter: ['checkPlatformVersions']
            quitOnError: true
        smQuitSplashScreen: enter: ['quitSplashScreen'], quitOnError: true
        smPermissions: enter: ['getPermissions'], quitOnError: true
        smConfig: enter: ['config'], quitOnError: true
        smRemoteRequest: enter: ['putRemoteRequest'], quitOnError: true
        smUpdateVersion: enter: ['updateVersion'], quitOnError: true
        smPostConfigInit: enter: ['postConfigInit'], quitOnError: true
        smSync: enter: ['postCopyViewSync'], quitOnError: true


    transitions:
        # Help :
        # initial_state: event: end_state

        # Start application
        'init':
            'startApplication': 'aDeviceLocale'
            'startService': 'sDeviceLocale'
        'aDeviceLocale': 'deviceLocaleSetted': 'aInitFileSystem'
        'aInitFileSystem': 'fileSystemReady': 'aInitDatabase'
        'aInitDatabase': 'databaseReady': 'aInitConfig'
        'aInitConfig':
            'configured': 'nPostConfigInit' # Normal start
            'newVersion': 'migrationInit' # Migration
            'notConfigured': 'fQuitSplashScreen' # First start
            # First start error
            'goTofDeviceName': 'f1QuitSplashScreen'
            'goTofInitContacts': 'f2QuitSplashScreen'
            'goTofInitCalendars': 'f3QuitSplashScreen'
            'goTofUpdateIndex': 'f4QuitSplashScreen'

        #######################################
        # Normal start
        'nPostConfigInit': 'initsDone': 'nQuitSplashScreen'
        'nQuitSplashScreen': 'viewInitialized': 'aLoadFilePage'
        'aLoadFilePage': 'onFilePage': 'aImport'
        'aImport': 'importDone': 'aBackup'
        'aBackup': 'backupDone': 'aRealtime'

        #######################################
        # Running
        'aPause': 'resume': 'aResume'
        'aResume': 'ready': 'aImport'

        'aRealtime':
            'pause': 'aPause'
            'openFile': 'aViewingFile'

        'aViewingFile': 'resume': 'aRealtime'

        #######################################
        # First start
        'fQuitSplashScreen': 'viewInitialized': 'fLogin'
        'fLogin': 'validCredentials': 'fPermissions'
        'fPermissions': 'getPermissions': 'fDeviceName'
        'fDeviceName': 'deviceCreated': 'fCheckPlatformVersion'
        'fCheckPlatformVersion': 'validPlatformVersions': 'fConfig'
        'fConfig': 'configDone': 'fFirstSyncView'
        'fFirstSyncView':
            'firstSyncViewDisplayed': 'fLocalDesignDocuments'
            'errorViewed': 'fConfig'
        'fLocalDesignDocuments':
            'localDesignUpToDate': 'fRemoteRequest'
            'errorViewed': 'fConfig'
        'fRemoteRequest':
            'putRemoteRequest':'fSetVersion'
            'errorViewed': 'fConfig'
        'fSetVersion':
            'versionUpToDate': 'fPostConfigInit'
            'errorViewed': 'fConfig'
        'fPostConfigInit':
            'initsDone': 'fTakeDBCheckpoint'
            'errorViewed': 'fConfig'
        'fTakeDBCheckpoint':
            'checkPointed': 'fInitFiles'
            'errorViewed': 'fConfig'
        'fInitFiles':
            'filesInited': 'fInitFolders'
            'errorViewed': 'fInitFiles'
        'fInitFolders':
            'foldersInited': 'fCreateAccount'
            'errorViewed': 'fInitFolders'
        'fCreateAccount':
            'androidAccountCreated': 'fInitContacts'
            'errorViewed': 'fCreateAccount'
        'fInitContacts':
            'contactsInited': 'fInitCalendars'
            'errorViewed': 'fInitContacts'
        'fInitCalendars':
            'calendarsInited': 'fSync'
            'errorViewed': 'fInitCalendars'
        'fSync':
            'dbSynced': 'fUpdateIndex'
            'errorViewed': 'fSync'
        'fUpdateIndex':
            'indexUpdated': 'aLoadFilePage'
            'errorViewed': 'aLoadFilePage'


        # First start error transitions
        # 1 error after before FirstSync End. --> Go to config.
        'f1QuitSplashScreen': 'viewInitialized': 'fCheckPlatformVersion'

        # 2 error after File sync
        'f2QuitSplashScreen': 'viewInitialized': 'f2FirstSyncView'
        'f2FirstSyncView': 'firstSyncViewDisplayed': 'f2PostConfigInit'
        'f2PostConfigInit': 'initsDone': 'fInitContacts'

        # 3 error after Contacts sync
        'f3QuitSplashScreen': 'viewInitialized': 'f3FirstSyncView'
        'f3FirstSyncView': 'firstSyncViewDisplayed': 'f3PostConfigInit'
        'f3PostConfigInit': 'initsDone': 'fInitCalendars'

        # 4 error after Calendars sync
        'f4QuitSplashScreen': 'viewInitialized': 'f4FirstSyncView'
        'f4FirstSyncView': 'firstSyncViewDisplayed': 'f4PostConfigInit'
        'f4PostConfigInit': 'initsDone': 'fUpdateIndex'

        #######################################
        # Start Service
        'sDeviceLocale': 'deviceLocaleSetted': 'sInitFileSystem'
        'sInitFileSystem': 'fileSystemReady': 'sInitDatabase'
        'sInitDatabase': 'databaseReady': 'sInitConfig'
        'sPostConfigInit': 'initsDone': 'sImport'
        'sImport': 'importDone': 'sSync'
        'sSync': 'syncDone': 'sBackup'
        'sBackup': 'backupDone': 'sSync2'
        'sSync2': 'syncDone': 'sQuit'
        'sInitConfig':
            'configured': 'sPostConfigInit' # Normal start
            'newVersion': 'smMigrationInit' # Migration

        #######################################
        # Config update
        ###################
        'c1RemoteRequest':
            'putRemoteRequest': 'c1TakeDBCheckpoint'
            'errorViewed': 'aRealtime'
        'c1TakeDBCheckpoint':
            'checkPointed': 'c1CreateAccount'
            'errorViewed': 'aRealtime'
        'c1CreateAccount':
            'androidAccountCreated': 'c1InitContacts'
            'errorViewed': 'aRealtime'
        'c1InitContacts':
            'contactsInited': 'cSync'
            'errorViewed': 'aRealtime'


        ###################
        'c2RemoteRequest':
            'putRemoteRequest': 'c2TakeDBCheckpoint'
            'errorViewed': 'aRealtime'
        'c2TakeDBCheckpoint':
            'checkPointed': 'c2CreateAccount'
            'errorViewed': 'aRealtime'
        'c2CreateAccount':
            'androidAccountCreated': 'c2InitCalendars'
            'errorViewed': 'aRealtime'
        'c2InitCalendars':
            'calendarsInited': 'cSync'
            'errorViewed': 'aRealtime'

        ###################
        'c3RemoteRequest':
            'putRemoteRequest': 'c3TakeDBCheckpoint'
            'errorViewed': 'aRealtime'
        'c3TakeDBCheckpoint':
            'checkPointed': 'c3CreateAccount'
            'errorViewed': 'aRealtime'
        'c3CreateAccount':
            'androidAccountCreated': 'c3InitContacts'
            'errorViewed': 'aRealtime'
        'c3InitContacts':
            'contactsInited': 'c3InitCalendars'
            'errorViewed': 'aRealtime'
        'c3InitCalendars':
            'calendarsInited': 'cSync'
            'errorViewed': 'aRealtime'

        ###################
        'c4RemoteRequest':
            'putRemoteRequest': 'cSaveConfig'
            'errorViewed': 'aRealtime'

        ###################
        'cSync':
            'dbSynced': 'cSaveConfig'
            'errorViewed': 'aRealtime'
        'cSaveConfig':
            'configSaved': 'cUpdateIndex'
            'errorViewed': 'aRealtime'
        'cUpdateIndex':
            'indexUpdated': 'aImport' #TODO : clean update headers
            'errorViewed': 'aRealtime'

        #######################################
        # Migration
        'migrationInit': 'migrationInited': 'mMoveCache'
        'mMoveCache': 'cacheMoved': 'mLocalDesignDocuments'
        'mLocalDesignDocuments':
            'localDesignUpToDate': 'mCheckPlatformVersions'
        'mCheckPlatformVersions': 'validPlatformVersions': 'mQuitSplashScreen'
        'mQuitSplashScreen': 'viewInitialized': 'mPermissions'
        'mPermissions': 'getPermissions': 'mConfig'
        'mConfig': 'configDone': 'mRemoteRequest'
        'mRemoteRequest': 'putRemoteRequest': 'mUpdateVersion'
        'mUpdateVersion': 'versionUpToDate': 'mPostConfigInit'
        'mPostConfigInit': 'initsDone': 'mSync'
        'mSync': 'dbSynced': 'aLoadFilePage' # Regular start.

        ###################
        # Migration in service
        'smMigrationInit': 'migrationInited': 'smMoveCache'
        'smMoveCache': 'cacheMoved': 'smLocalDesignDocuments'
        'smLocalDesignDocuments':
            'localDesignUpToDate': 'smCheckPlatformVersions'
        'smCheckPlatformVersions': 'validPlatformVersions': 'smPermissions'
        'smPermissions': 'getPermissions': 'smConfig'
        'smConfig': 'configDone': 'smRemoteRequest'
        'smRemoteRequest': 'putRemoteRequest': 'smUpdateVersion'
        'smUpdateVersion': 'versionUpToDate': 'smPostConfigInit'
        'smPostConfigInit': 'initsDone': 'smSync'
        'smSync': 'dbSynced': 'sImport'

    # Enter state methods.
    setDeviceLocale: ->
        app.setDeviceLocale @getCallbackTrigger 'deviceLocaleSetted'


    initFileSystem: ->
        app.replicator.initFileSystem @getCallbackTrigger 'fileSystemReady'


    initDatabase: ->
        app.replicator.initDB  @getCallbackTrigger 'databaseReady'


    initConfig: ->
        app.replicator.initConfig (err, config) =>
            return @handleError err if err
            if config.remote
                # Check last state
                # If state is "ready" -> newVersion ? newVersion : configured
                # Else : go to this state (with preconditions checks ?)
                lastState = config.get('lastInitState') or 'aLoadFilePage'

                # Watchdog
                if lastState not in ['aLoadFilePage', 'fDeviceName',
                'fInitContacts', 'fInitCalendars', 'fUpdateIndex']
                    return @trigger 'goTofDeviceName'

                if lastState is 'aLoadFilePage' # Previously in normal start.
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
        app.postConfigInit @getCallbackTrigger 'initsDone'

    import: ->
        changesImporter = new ChangesImporter()
        changesImporter.synchronize (err) =>
            log.error err if err
            @trigger 'importDone'

    backup: ->
        app.replicator.startRealtime()
        app.replicator.backup {}, (err) =>
            log.error err if err
            @trigger 'backupDone'

    onResume: ->
        # Don't import, backup, ... while service still running
        app.serviceManager.isRunning (err, running) =>
            return log.error err if err

            # If service still running, try again later
            if running
                setTimeout (() => @onResume()), 10 * 1000
                log.info 'Service still running, backup later'

            else
                @trigger 'ready'

    onPause: ->
        @stopRealtime()

    startRealtime: ->
        app.replicator.startRealtime()

    stopRealtime: ->
        app.replicator.stopRealtime()

    quitSplashScreen: ->
        app.layout.quitSplashScreen()
        Backbone.history.start()
        @trigger 'viewInitialized'

    setListeners: ->
        app.setListeners()

    loadFilePage: ->
        app.router.navigate 'folder/', trigger: true
        app.router.once 'collectionfetched', => @trigger 'onFilePage'




    upsertLocalDesignDocuments: ->
        return if @passUnlessInMigration 'localDesignUpToDate'

        app.replicator.upsertLocalDesignDocuments \
            @getCallbackTrigger 'localDesignUpToDate'


    checkPlatformVersions: ->
        return if @passUnlessInMigration 'validPlatformVersions'
        app.replicator.checkPlatformVersions (err, response) =>
            if err
                if app.layout.currentView
                    # currentView is device-name view
                    return app.layout.currentView.displayError err.message
                else
                    alert err.message
                    return app.exit()

            @trigger 'validPlatformVersions'


    getPermissions: ->
        return if @passUnlessInMigration 'getPermissions'

        if app.replicator.config.hasPermissions(app.replicator.permissions)
            @trigger 'getPermissions'
        else if @currentState is 'smPermissions'
            app.startMainActivity 'smPermissions'
        else
            app.router.navigate 'permissions', trigger: true


    putRemoteRequest: ->
        return if @passUnlessInMigration 'putRemoteRequest'

        app.replicator.putRequests (err) =>

            app.replicator.putFilters @getCallbackTrigger 'putRemoteRequest'


    updateVersion: ->
        app.replicator.config.updateVersion \
            @getCallbackTrigger 'versionUpToDate'


    # First start
    login: ->
        app.router.navigate 'login', trigger: true

    setDeviceName: -> app.router.navigate 'device-name-picker', trigger: true

    config: ->
        return if @passUnlessInMigration 'configDone'
        if @currentState is 'smConfig'
            app.startMainActivity 'smConfig'
        else
            app.router.navigate 'config', trigger: true

    updateCozyLocale: -> app.replicator.updateLocaleFromCozy \
        @getCallbackTrigger 'cozyLocaleUpToDate'

    firstSyncView: ->
        app.router.navigate 'first-sync', trigger: true
        @trigger 'firstSyncViewDisplayed'

    takeDBCheckpoint: ->
        app.replicator.takeCheckpoint \
            @getCallbackTrigger 'checkPointed'

    initFiles: ->
        app.replicator.copyView docType: 'file', \
            @getCallbackTrigger 'filesInited'

    initFolders: ->
        app.replicator.copyView docType: 'folder', \
            @getCallbackTrigger 'foldersInited'

    createAndroidAccount: ->
        if app.replicator.config.get('syncContacts') or \
                app.replicator.config.get('syncCalendars')
            androidAccount = new AndroidAccount()
            androidAccount.create @getCallbackTrigger 'androidAccountCreated'

        else
            @trigger 'androidAccountCreated' # TODO: rename event.

    # 1. Copy view for contact
    # 2. dispatch inserted contacts to android through the change dispatcher
    initContacts: ->
        if app.replicator.config.get('syncContacts')
            changeDispatcher = new ChangeDispatcher()
            # 1. Copy view for contact
            app.replicator.copyView
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
        if app.replicator.config.get('syncCalendars')
            changeDispatcher = new ChangeDispatcher()
            # 1. Copy view for event
            app.replicator.copyView docType: 'event', (err, events) =>
                return @handleError err if err
                async.eachSeries events, (event, cb) ->
                    # 2. dispatch inserted events to android
                    changeDispatcher.dispatch event, cb
                , @getCallbackTrigger 'calendarsInited'
        else
            @trigger 'calendarsInited' # TODO: rename event to noSyncCalendars


    postCopyViewSync: ->
        return if @passUnlessInMigration 'dbSynced'

        # Get the local last seq :
        app.replicator.db.changes
            descending: true
            limit: 1
        , (err, changes) =>
            localCheckpoint = changes.last_seq

            app.replicator.sync
                remoteCheckpoint: app.replicator.config.get('checkpointed')
                localCheckpoint: localCheckpoint
            , (err) =>
                return @handleError err if err

                # Copy view is done. Unset this transition var.
                app.replicator.config.unset 'checkpointed'
                @trigger 'dbSynced'


    updateIndex: ->
        app.replicator.updateIndex @getCallbackTrigger 'indexUpdated'

    saveConfig: ->
        app.replicator.config.save @getCallbackTrigger 'configSaved'
    ###########################################################################
    # Service
    sInitConfig: ->
        app.replicator.initConfig (err, config) =>
            return @handleError err if err
            return @handleError new Error('notConfigured') unless config.remote


            # Check last state
            # If state is "ready" -> newVersion ? newVersion : configured
            # Else : go to this state (with preconditions checks ?)
            lastState = config.get('lastInitState') or 'aLoadFilePage'

            if lastState is 'aLoadFilePage' # Previously in normal start.
                if config.isNewVersion()
                    @trigger 'newVersion'
                else
                    @trigger 'configured'
            else # In init.
                return @handleError new Error "notConfigured: #{lastState}"
    sBackup: ->
        app.replicator.backup background: true
        , @getCallbackTrigger 'backupDone'

    sSync: ->
        app.replicator.sync {}, @getCallbackTrigger 'syncDone'

    sQuit: ->
        app.exit()

    ###########################################################################
    # Tools
    saveState: ->
        app.replicator.config.save lastInitState: @currentState
        , (err, config) -> log.warn err if err

    # show the error to the user appropriately regarding to the current state
    handleError: (err) ->
        if @states[@currentState].quitOnError
            app.exit err
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


    passUnlessInMigration: (event) ->
        state = @currentState

        # Convert service states.
        if state.indexOf('s') is 0
            state = state.slice 1

        if state.indexOf('m') is 0 and state not of @migrationStates
            log.info "Skip state #{state} during migration so fire #{event}."
            @trigger event
            return true
        else
            return false


    initMigrations: (oldVersion) ->
        oldVersion ?= '0.0.0'
        for version, migration of @migrations
            if semver.gt(version, oldVersion)
                for state in migration.states
                    @migrationStates[state] = true

    ###########################################################################

    # Migrations
    # For each version update, list which optionnal states are requiered in
    # - mLocalDesignDocuments
    # - mCheckPlatformVersions
    # - mPermissions
    # - mConfig
    # - mRemoteRequest
    migrations:
        '0.2.1': # Move cache root directory to external storage cache
            states: [ 'mMoveCache']
        '0.2.0':
            # Filters: upper version of platform requiered.
            states: ['mLocalDesignDocuments', 'mCheckPlatformVersions', \
                     'mRemoteRequest', 'mSync']
        '0.1.15':
            # New routes, calendar sync.
            states: ['mCheckPlatformVersions', 'mPermissions', 'mRemoteRequest']


    # Migration
    initMigrationState: ->
        @initMigrations app.replicator.config.get 'appVersion'
        @trigger 'migrationInited'

    # Move cache from old "/cozy-downloads" to external storage application
    # Cache directory
    migrationMoveCache: ->
        return if @passUnlessInMigration 'cacheMoved'
        return @trigger 'cacheMoved' if window.isBrowserDebugging

        fs = require './filesystem'

        getOldDownloadsDir = (callback) ->
            uri = cordova.file.externalRootDirectory \
                or cordova.file.cacheDirectory
            window.resolveLocalFileSystemURL uri
            , (res) ->
                fs.getDirectory res.filesystem.root, 'cozy-downloads', callback

            , callback

        checkFolderDeleted = (callback) ->
            getOldDownloadsDir (err, dir) ->
                if err?.code is 1
                    callback()
                else
                    log.info "cache migration not finished yet, check later."
                    setTimeout ( -> checkFolderDeleted callback), 500

        async.parallel
            newFS: fs.getFileSystem
            oldDownloads: getOldDownloadsDir
        , (err, res) =>
            if err
                log.error err
                @handleError new Error 'moving synced files to new directory'
                # Continue on error : the user can fix it itself.
                return @trigger 'cacheMoved'

            # fs.moveTo doesn't look to call its callback in this situation !?
            fs.moveTo res.oldDownloads, res.newFS.root, 'cozy-downloads'
            , (err, folder) ->
                log.warning "migrationMoveTo done ! ", err, folder

            # Busy waiting for old dir deletion
            checkFolderDeleted \
                # Update cache info in replicator
                app.replicator.initFileSystem @getCallbackTrigger 'cacheMoved'
