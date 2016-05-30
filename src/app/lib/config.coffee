log = require("./persistent_log")
    prefix: "Config"
    date: true

APP_VERSION = "1.3.1"
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

    syncContacts: true
    syncCalendars: true
    syncImages: true
    syncOnWifi: true
    cozyNotifications: false

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

                configClone = JSON.parse JSON.stringify config
                configClone.devicePassword = '********************'
                log.info "Start v#{APP_VERSION} -- \
                          config: #{JSON.stringify configClone}"

                @database.setRemoteDatabase @getCozyUrl() if @getCozyUrl()
                @loaded = true
                return callback err, true

            log.info 'Initialize app configuration'
            config = DEFAULT_CONFIG
            config.deviceName = "Android-#{device.manufacturer}-#{device.model}"
            setConfig @database.replicateDb, (err) =>
                log.error err if err
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
            serializePermissions(@get('devicePermissions')),
            serializePermissions(PERMISSIONS)


module.exports = Config
