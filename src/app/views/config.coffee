BaseView = require '../lib/base_view'
Config = require '../lib/config'


log = require('../lib/persistent_log')
    prefix: "config view"
    date: true

module.exports = class ConfigView extends BaseView

    @SUPPORT_MAIL: 'log-mobile@cozycloud.cc'
    template: require '../templates/config'

    menuEnabled: true

    events: ->
        'tap #configDone': 'configDone'
        'tap #redbtn': 'redBtn'
        'tap #synchrobtn': 'synchroBtn'
        'tap #sendlogbtn': 'sendlogBtn'

        'change #contactSyncCheck': 'saveChanges'
        'change #calendarSyncCheck': 'saveChanges'
        'change #imageSyncCheck': 'saveChanges'
        'change #wifiSyncCheck': 'saveChanges'
        'change #cozyNotificationsCheck' : 'saveChanges'

    getRenderData: ->
        log.debug "getRenderData"

        config = window.app.init.config

        cozyURL: config.get 'cozyURL'
        syncContacts: config.get 'syncContacts'
        syncCalendars: config.get 'syncCalendars'
        syncImages: config.get 'syncImages'
        syncOnWifi: config.get 'syncOnWifi'
        cozyNotifications: config.get 'cozyNotifications'
        deviceName: config.get 'deviceName'
        lastSync: @formatDate config.get 'lastSync'
        lastBackup: @formatDate config.get 'lastBackup'
        initState: app.init.currentState
        locale: app.locale
        appVersion: config.get 'appVersion'

    # format a object as a readable date string
    # return t('never') if undefined
    formatDate: (date) ->
        log.debug "formatDate #{date}"

        return t 'never' if not date or date is ''

        date = moment(date)
        return date.format 'YYYY-MM-DD HH:mm:ss'

    # only happens after the first config (post install)
    configDone: ->
        app.init.trigger 'configDone'


    # confirm, destroy the DB, force refresh the page (show login form)
    redBtn: ->
        if confirm t 'confirm message'
            #@TODO delete device on remote ?
            app.init.replicator.set 'inSync', true # run the spinner
            app.init.replicator.set 'backup_step', 'destroying database'
            app.init.replicator.destroyDB (err) ->
                if err
                    log.error err
                    return alert err.message
                $('#redbtn').text t 'done'

                # DeviceStatus has to be stopped to restart properly.
                require('../lib/device_status').shutdown()
                window.location.reload true


    # confirm, launch initial replication, navigate to first sync UI.
    synchroBtn: ->
        if confirm t 'confirm message'
            app.init.replicator.stopRealtime()
            app.init.toState 'fFirstSyncView'


    sendlogBtn: ->
        config = window.app.init.config
        subject = "Log from cozy-mobile v#{config.get 'appVersion'}"
        body = """
            #{t('send log please describe problem')}


            ########################
            # #{t('send log trace begin')}
            ##

            #{log.getTraces().join('\n')}

            ##
            # #{t('send log trace end')}
            ########################


            #{t('send log please describe problem')}

            """

        query = "subject=#{encodeURI(subject)}&body=#{encodeURI(body)}"

        window.open "mailto:#{ConfigView.SUPPORT_MAIL}?" + query, "_system"


    # save config changes in local pouchdb
    # prevent simultaneous changes by disabling checkboxes
    saveChanges: ->
        # disabl UI
        # put changes in replicatorConfig object
        # perform sync /init required
        # rollback on error
        # save in config on success.

        log.info "Save changes"
        checkboxes = @$ '#contactSyncCheck, #imageSyncCheck,' +
                        '#wifiSyncCheck, #cozyNotificationsCheck' +
                        '#configDone, #calendarSyncCheck'
        checkboxes.prop 'disabled', true

        @listenToOnce app.init, 'configSaved error', =>
            checkboxes.prop 'disabled', false
            @render()

        app.init.updateConfig @_updateAndGetInitNeeds
            syncContacts: @$('#contactSyncCheck').is ':checked'
            syncCalendars: @$('#calendarSyncCheck').is ':checked'
            syncImages: @$('#imageSyncCheck').is ':checked'
            syncOnWifi: @$('#wifiSyncCheck').is ':checked'
            cozyNotifications: @$('#cozyNotificationsCheck').is ':checked'

    _updateAndGetInitNeeds: (changes) ->
        config = window.app.init.config
        needInit =
            cozyNotifications: changes.cozyNotifications and \
                (changes.cozyNotifications isnt config.get 'cozyNotifications')
            syncCalendars: changes.syncCalendars and \
                (changes.syncCalendars isnt config.get 'syncCalendars')
            syncContacts: changes.syncContacts and \
                (changes.syncContacts isnt config.get 'syncContacts')

        for key, value of changes
            config.set key, value

        return needInit
