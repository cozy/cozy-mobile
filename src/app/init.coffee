semver = require 'semver'
async = require 'async'
ChangeDispatcher = require './replicator/change/change_dispatcher'
ChangesImporter = require './replicator/fromDevice/changes_importer'
AndroidAccount = require './replicator/fromDevice/android_account'
validator = require 'validator'
ServiceManager = require './models/service_manager'
Notifications  = require './views/notifications'
DeviceStatus   = require './lib/device_status'
Replicator = require './replicator/main'
Translation = require './lib/translation'
Config = require './lib/config'
Database = require './lib/database'
RequestCozy = require './lib/request_cozy'
FilterManager = require './replicator/filter_manager'

log = require('./lib/persistent_log')
    prefix: "Init"
    date: true


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

    constructor: (@app) ->
        log.debug "constructor"

        @migrationStates = {}
        @translation = new Translation()
        @database = new Database()
        @config = new Config @database
        @replicator = new Replicator()
        @requestCozy = new RequestCozy @config
        @replicator.initConfig @config, @requestCozy, @database

        @listenTo @, 'transition', (leaveState, enterState) =>

            log.info "Transition from state #{leaveState} \
                      to state #{enterState}"

            if @states[enterState]?.display?
                @trigger 'display', @states[enterState].display

            # Hide display if no needed in comming state.
            else if @states[leaveState]?.display?
                @trigger 'noDisplay'

        return @


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
        # - m : migration start
        # - sm : migration in service start

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
        fCheckURL       : enter: ['checkURL']
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
        smSync: enter: ['postCopyViewSync'], quitOnError: true


    transitions:
        # Help :
        # initial_state: event: end_state

        'init':
            'startApplication': 'aConfigLoad'
            'startService': 'sConfigLoad'

        ########################################
        # Start application
        'aConfigLoad': 'loaded': 'aDeviceLocale'
        'aDeviceLocale': 'deviceLocaleSetted': 'aInitFileSystem'
        'aInitFileSystem': 'fileSystemReady': 'aQuitSplashScreen'
        'aQuitSplashScreen': 'viewInitialized': 'aCheckState'
        'aCheckState':
            'migration': 'migrationInit'
            'default': 'fWizardWelcome'
            'deviceCreated': 'fWizardFiles'
            'appConfigured': 'fFirstSyncView'
            'syncCompleted': 'nLoadFilePage'

        #######################################
        # Start Service
        'sConfigLoad': 'loaded': 'sCheckState'
        'sCheckState':
            'migration': 'smMigrationInit'
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
            'clickNext': 'fCheckURL'
        'fCheckURL':
            'clickToPassword': 'fWizardPassword'
            'error': 'fWizardURL'
        'fWizardPassword':
            'clickBack': 'fWizardURL'
            'validCredentials': 'fCreateDevice'
        'fCreateDevice':
            'deviceCreated': 'fWizardFiles'
            'errorViewed': 'fConfig'
        'fWizardFiles'   : 'clickNext': 'fWizardContacts'
        'fWizardContacts':
            'clickBack': 'fWizardFiles'
            'clickNext': 'fWizardCalendars'
        'fWizardCalendars':
            'clickBack': 'fWizardContacts'
            'clickNext': 'fWizardPhotos'
        'fWizardPhotos'  :
            'clickBack': 'fWizardCalendars'
            'clickNext': 'fFirstSyncView'
        'fFirstSyncView': 'firstSyncViewDisplayed': 'fCheckPlatformVersion'
        'fCheckPlatformVersion':
            'validPlatformVersions': 'fLocalDesignDocuments'
            'errorViewed': 'fConfig'
        'fLocalDesignDocuments':
            'localDesignUpToDate': 'fRemoteRequest'
            'errorViewed': 'fConfig'
        'fRemoteRequest':
            'putRemoteRequest':'fSetVersion'
            'errorViewed': 'fConfig'
        'fSetVersion':
            'versionUpToDate': 'fTakeDBCheckpoint'
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

        #######################################
        # Migration
        'migrationInit': 'migrationInited': 'mMoveCache'
        'mMoveCache': 'cacheMoved': 'mLocalDesignDocuments'
        'mLocalDesignDocuments': 'localDesignUpToDate': 'mCheckPlatformVersions'
        'mCheckPlatformVersions': 'validPlatformVersions': 'mQuitSplashScreen'
        'mQuitSplashScreen': 'viewInitialized': 'mPermissions'
        'mPermissions': 'getPermissions': 'mConfig'
        'mConfig': 'configDone': 'mRemoteRequest'
        'mRemoteRequest': 'putRemoteRequest': 'mUpdateVersion'
        'mUpdateVersion': 'versionUpToDate': 'mSync'
        'mSync': 'dbSynced': 'nLoadFilePage' # Regular start.

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
        'smUpdateVersion': 'versionUpToDate': 'smSync'
        'smSync': 'dbSynced': 'sImport'

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
                @trigger 'loaded'

    setDeviceLocale: ->
        DeviceStatus.initialize()
        unless window.isBrowserDebugging # Patch for browser debugging
            @notificationManager = new Notifications()

            # The ServiceManager is a flag for the background plugin to know if
            # it's the service or the application, see https://git.io/vVjJO
            @serviceManager = new ServiceManager() unless @app.name is 'SERVICE'

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




    upsertLocalDesignDocuments: ->
        return if @passUnlessInMigration 'localDesignUpToDate'

        @replicator.upsertLocalDesignDocuments \
            @getCallbackTrigger 'localDesignUpToDate'


    checkPlatformVersions: ->
        return if @passUnlessInMigration 'validPlatformVersions'
        @replicator.checkPlatformVersions (err, response) =>
            if err
                if @app.layout.currentView
                    # currentView is device-name view
                    return @app.layout.currentView.displayError err.message
                else
                    alert err.message
                    return @app.exit()

            @trigger 'validPlatformVersions'


    getPermissions: ->
        return if @passUnlessInMigration 'getPermissions'

        if @config.hasPermissions()
            @trigger 'getPermissions'
        else if @currentState is 'smPermissions'
            @app.startMainActivity 'smPermissions'
        else
            @app.router.navigate 'permissions', trigger: true


    putRemoteRequest: ->
        return if @passUnlessInMigration 'putRemoteRequest'

        @replicator.putRequests (err) =>
            @trigger 'putRemoteRequest'


    updateVersion: ->
        @config.updateVersion @getCallbackTrigger 'versionUpToDate'


    # First start
    loginWizard: ->
        @app.router.navigate "login/#{@currentState}", trigger: true

    checkURL: ->
        url = @config.get 'cozyURL'
        isLocalhost = url.indexOf('localhost') is 0
        protocols = ['https']
        if window.isBrowserDebugging and isLocalhost
            protocols.push 'http'

        options =
            protocols: protocols
        if validator.isURL url, options
            @trigger 'clickToPassword'
        else
            @trigger 'error', new Error t "Your Cozy URL is not valid."

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
        return if @passUnlessInMigration 'configDone'
        if @currentState is 'smConfig'
            @app.startMainActivity 'smConfig'
        else
            @app.router.navigate 'config', trigger: true

    updateCozyLocale: -> @replicator.updateLocaleFromCozy \
        @getCallbackTrigger 'cozyLocaleUpToDate'

    firstSyncView: ->
        @app.router.navigate 'first-sync', trigger: true
        db = @database.replicateDb
        filterManager = new FilterManager @config, @requestCozy, db
        filterManager.setFilter =>
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
        return if @passUnlessInMigration 'dbSynced'

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
        @initMigrations @config.get 'appVersion'
        @trigger 'migrationInited'

    # Move cache from old "/cozy-downloads" to external storage application
    # Cache directory
    migrationMoveCache: ->
        return if @passUnlessInMigration 'cacheMoved'
        return @trigger 'cacheMoved' if window.isBrowserDebugging

        fs = require './replicator/filesystem'

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
                @replicator.initFileSystem @getCallbackTrigger 'cacheMoved'
