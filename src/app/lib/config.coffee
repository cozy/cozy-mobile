log = require("./persistent_log")
    prefix: "Config"
    date: true

APP_VERSION = "1.1.0"
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
    permissions: PERMISSIONS

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

    load: (callback) ->
        log.debug "load"

        getConfig @database.localDb, (err, doc) =>
            if doc
                config = doc

                log.info "Start v#{APP_VERSION} -- \
                          config: #{JSON.stringify config}"

                @database.setRemoteDatabase @getCozyUrl()
                return callback err, true

            config = DEFAULT_CONFIG
            config.deviceName = "Android-#{device.manufacturer}-#{device.model}"
            setConfig @database.localDb, (err) =>
                # todo: error ?
                @load callback


    get: (key) ->
        log.debug "get for key: #{key}"

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

        value = serializePermissions value if key is 'permissions'

        if config[key] isnt value
            config[key] = value
            setConfig @database.localDb, callback
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

    setCozyUrl: (url) ->
        log.debug 'setCozyUrl'

        @set 'cozyURL', url
        if url[0..7] is 'https://'
            protocol = 'https://'
        else
            protocol = 'http://'
        url = url.replace protocol, ''
        @set 'cozyHostname', url
        @set 'cozyProtocol', protocol


    # version

    isNewVersion: ->
        log.debug 'isNewVersion'
        APP_VERSION isnt @get 'appVersion'

    updateVersion: (callback) ->
        log.debug 'updateVersion'
        if @isNewVersion() then @set 'appVersion', APP_VERSION, callback
        else callback()


    # permission

    hasPermissions: ->
        _.isEqual \
            serializePermissions(@get('permissions')),
            serializePermissions(PERMISSIONS)

module.exports = Config
