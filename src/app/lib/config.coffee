log = require("./persistent_log")
    prefix: "Config"
    date: true

APP_VERSION = "2.0.0"
DOC_ID = '_local/appconfig'
PERMISSIONS =
    File: description: "files permission description"
    Folder: description: "folder permission description"
    Binary: description: "binary permission description"
    Contact: description: "contact permission description"
    Event: description: "event permission description"
    Notification: description: "notification permission description"
    Tag: description: "tag permission description"
DEFAULT_CONFIG =
    _id: DOC_ID
    # state :
    #  - default
    #  - deviceCreated
    #  - appConfigured
    #  - syncCompleted
    state: 'default'
    # appState :
    #  - launch
    #  - pause
    #  - service
    appState: 'launch'
    appVersion: APP_VERSION

    syncContacts: false
    syncCalendars: false
    syncImages: false
    syncOnWifi: true
    cozyNotifications: false
    firstSyncFiles: false
    firstSyncContacts: false
    firstSyncCalendars: false

    cozyURL: ''
    cozyHostname: ''
    cozyProtocol: ''

    deviceName: ''
    devicePassword: ''
    devicePermissions: PERMISSIONS

    lastSync: ''
    lastBackup: ''

# Private


config = {}


getConfig = (db, callback) ->
    db.get DOC_ID, callback


setConfig = (db, callback) ->
    getConfig db, (err, doc) ->
        unless err # may be 404, at doc initialization.
            config._rev = doc._rev

        delete config.password if config.password

        db.put config, (err, res) ->
            return callback err if err
            return callback new Error('cant save config') unless res.ok

            callback null, true


serializePermissions = (permissions) ->
    Object.keys(permissions).sort()


# Public


class Config


    constructor: (@database) ->
        log.debug "constructor"

        @loaded = false
        _.extend @, Backbone.Events


    display: ->
        configClone = JSON.parse JSON.stringify config
        configClone.devicePassword = '********************'
        log.info "Start v#{APP_VERSION} -- \
                          config: #{JSON.stringify configClone}"


    load: (callback) ->
        log.debug "load"

        getConfig @database.replicateDb, (err, doc) =>
            if doc

                config = doc

                if @isNewVersion()
                    return app.init.upsertLocalDesignDocuments =>
                        migration = require '../migrations/migration'
                        return migration.migrate doc.appVersion, =>
                            @load callback

                @display()

                @database.setRemoteDatabase @getCozyUrl() if @getCozyUrl()
                @loaded = true
                return callback err, true

            log.info 'Initialize app configuration'

            config = DEFAULT_CONFIG
            config.deviceName = "#{device.platform}-#{device.manufacturer}-#{device.model}"
            setConfig @database.replicateDb, (err) =>
                log.error err if err
                app.init.upsertLocalDesignDocuments =>
                    @load callback


    setConfigValue: (newConfig) ->
        config = newConfig


    get: (key) ->
        err = null
        unless key of DEFAULT_CONFIG # verify valid key
            err = new Error "This configuration key (#{key}) is invalid."

        if config[key] is undefined
            err = new Error "Configuration isn't loaded."

        if err
            log.error err
            return

        config[key]


    set: (key, value, callback = ->) ->
        log.debug "set for key: #{key}"

        unless key of DEFAULT_CONFIG # verify valid key
            err = new Error "This configuration key (#{key}) is invalid."
            return log.error err

        value = serializePermissions value if key is 'devicePermissions'

        if config[key] isnt value
            config[key] = value
            setConfig @database.replicateDb, callback

            @trigger "change:#{key}", @, value
        else
            callback()


    # cozy url


    getCozyUrl: ->
        log.debug 'getCozyUrl'

        cozyUrl = @get 'cozyProtocol'
        deviceName = @get 'deviceName'
        devicePassword = @get 'devicePassword'

        if deviceName and devicePassword
            cozyUrl += "#{deviceName}:#{devicePassword}@"

        cozyUrl += @get 'cozyHostname'


    setCozyUrl: (url, callback = ->) ->
        log.debug 'setCozyUrl'

        protocol = if url[0..6] is 'http://' then 'http://' else 'https://'
        url = protocol + url unless url[0..3] is 'http'

        @set 'cozyURL', url, (err) =>
            return callback err if err
            hostname = url.replace protocol, ''
            @set 'cozyHostname', hostname, (err) =>
                return callback err if err
                @set 'cozyProtocol', protocol, callback



    # version


    isNewVersion: ->
        log.debug 'isNewVersion'

        APP_VERSION isnt @get 'appVersion'


    updateVersion: (callback) ->
        log.debug 'updateVersion'

        if @isNewVersion() then @set 'appVersion', APP_VERSION, callback
        else callback()


    # permission


    getDefault: -> DEFAULT_CONFIG


    getDefaultPermissions: -> PERMISSIONS


    hasPermissions: ->
        _.isEqual \
            @get('devicePermissions'),
            serializePermissions(PERMISSIONS)


    removeSync: (type) ->
        if type is 'contacts'
            @set 'syncContacts', false
        else if type is 'calendars'
            @set 'syncCalendars', false
        else if type is 'files' or type is 'photos'
            @set 'syncImages', false


    firstSyncIsDone: ->
        if not @get('firstSyncFiles') or \
                (@get('syncContacts') and not @get('firstSyncContacts')) or \
                (@get('syncCalendars') and not @get('firstSyncCalendars'))
            return false
        true


module.exports = Config
