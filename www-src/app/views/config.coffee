BaseView = require '../lib/base_view'


log = require('/lib/persistent_log')
    prefix: "config view"
    date: true

module.exports = class ConfigView extends BaseView

    template: require '../templates/config'

    menuEnabled: true

    events: ->
        'tap #configDone': 'configDone'
        'tap #redbtn': 'redBtn'
        'tap #synchrobtn': 'synchroBtn'
        'tap #sendlogbtn': 'sendlogBtn'

        'tap #contactSyncCheck': 'saveChanges'
        'tap #imageSyncCheck': 'saveChanges'
        'tap #wifiSyncCheck': 'saveChanges'
        'tap #cozyNotificationsCheck' : 'saveChanges'

    getRenderData: ->
        config = app.replicator.config.toJSON()

        return _.extend {},
            config,
            lastSync: @formatDate config?.lastSync
            lastBackup: @formatDate config?.lastBackup
            firstRun: app.isFirstRun
            locale: app.locale
            appVersion: app.replicator.config.appVersion()

    # format a object as a readable date string
    # return t('never') if undefined
    formatDate: (date) ->
        unless date then return t 'never'
        else
            date = new Date(date) unless date instanceof Date
            return date.toISOString().slice(0, 19).replace('T', ' ')


    # only happens after the first config (post install)
    configDone: ->
        app.router.navigate 'first-sync', trigger: true


    # confirm, destroy the DB, force refresh the page (show login form)
    redBtn: ->
        if confirm t 'confirm message'
            #@TODO delete device on remote ?
            app.replicator.set 'inSync', true # run the spinner
            app.replicator.set 'backup_step', 'destroying database'
            app.replicator.destroyDB (err) =>
                if err
                    log.error err
                    return alert err.message
                $('#redbtn').text t 'done'

                # DeviceStatus has to be stopped to restart properly.
                require('lib/device_status').shutdown()
                window.location.reload true


    # confirm, launch initial replication, navigate to first sync UI.
    synchroBtn: ->
        if confirm t 'confirm message'
            app.router.navigate 'first-sync', trigger: true


    sendlogBtn: ->
        subject = "Log from cozy-mobile v" + app.replicator.config.appVersion()
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

        window.open "mailto:guillaume@cozycloud.cc?" + query, "_system"


    # save config changes in local pouchdb
    # prevent simultaneous changes by disabling checkboxes
    saveChanges: ->
        log.info "Save changes"
        checkboxes = @$ '#contactSyncCheck, #imageSyncCheck,' +
                        '#wifiSyncCheck, #cozyNotificationsCheck' +
                        '#configDone'
        checkboxes.prop 'disabled', true


        app.replicator.config.save
            syncContacts: @$('#contactSyncCheck').is ':checked'
            syncImages: @$('#imageSyncCheck').is ':checked'
            syncOnWifi: @$('#wifiSyncCheck').is ':checked'
            cozyNotifications: @$('#cozyNotificationsCheck').is ':checked'

        , ->
            checkboxes.prop 'disabled', false

