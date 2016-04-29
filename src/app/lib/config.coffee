semver = require 'semver'
log = require("./persistent_log")
    prefix: "Config"
    date: true

APP_VERSION = "1.2.0"
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


migrateOldConfiguration = (db, callback) ->
    newConfig = {}
    db.get DEFAULT_CONFIG._id, (err, doc) ->
        return callback err if err

        # remove auth
        # remove lastInitState
        # add state
        for key of DEFAULT_CONFIG
            if doc[key] isnt undefined
                newConfig[key] = doc[key]
            else
                newConfig[key] = DEFAULT_CONFIG[key]

        newConfig.appVersion = APP_VERSION
        newConfig._rev = doc._rev
        if doc.lastBackup > 0 or doc.lastSync > 0
            newConfig.state = 'syncCompleted'

        config = newConfig
        db.put newConfig, callback


# Public


class Config

    constructor: (@database) ->
        log.debug "constructor"

        _.extend @, Backbone.Events

    load: (callback) ->
        log.debug "load"

        getConfig @database.replicateDb, (err, doc) =>
            if doc

                if semver.gt APP_VERSION, doc.appVersion
                    db = @database.replicateDb
                    return migrateOldConfiguration db, (err) =>
                        return callback err if err
                        @setCozyUrl @get('cozyURL'), =>
                            @load callback

                config = doc

                log.info "Start v#{APP_VERSION} -- \
                          config: #{JSON.stringify config}"

                @database.setRemoteDatabase @getCozyUrl() if @getCozyUrl()
                return callback err, true

            config = DEFAULT_CONFIG
            config.deviceName = "Android-#{device.manufacturer}-#{device.model}"
            setConfig @database.replicateDb, (err) =>
                # todo: error ?
                @load callback


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
