log = require('./persistent_log')
    prefix: "log sender"
    date: true

SUPPORT_MAIL = 'log-mobile@cozycloud.cc'

module.exports =

    getData: ->
        config = window.app.init.config

        return {
            subject: "Log from cozy-mobile v#{config.get 'appVersion'}"
            body: """
                  #{t('send log please describe problem')}


                  ########################
                  # #{device.platform}: #{device.version}
                  # url: '#{config.get 'cozyURL'}'
                  # deviceName: '#{config.get 'deviceName'}'
                  # version: '#{config.get 'appVersion'}'
                  #
                  # syncContacts: '#{config.get 'syncContacts'}'
                  # syncCalendars: '#{config.get 'syncCalendars'}'
                  # syncNotifications: '#{config.get 'cozyNotifications'}'
                  #
                  # syncImages: '#{config.get 'syncImages'}'
                  # syncOnWifi: '#{config.get 'syncOnWifi'}'
                  #
                  # firstSyncFiles: '#{config.get 'firstSyncFiles'}'
                  # firstSyncContacts: '#{config.get 'firstSyncContacts'}'
                  # firstSyncCalendars: '#{config.get 'firstSyncCalendars'}'
                  #
                  # #{t('send log trace begin')}
                  ##

                  #{log.getTraces().join('\n')}

                  ##
                  # #{t('send log trace end')}
                  ########################


                  #{t('send log please describe problem')}

                  """
        }

    send: ->
        data = @getData()

        query = "subject=#{encodeURI(data.subject)}" + \
                "&body=#{encodeURI(data.body)}"

        window.open "mailto:#{SUPPORT_MAIL}?" + query, "_system"


    share: ->
        data = @getData()
        options =
            subject: data.subject
            message: data.body
        onSuccess = (result) ->
            log.info "Share completed? " + result.completed
            log.info "Shared to app: " + result.app
        onError = (err) ->
            log.info "Sharing failed with message: " + err
        socialSharing = window.plugins.socialsharing
        socialSharing.shareWithOptions options, onSuccess, onError

