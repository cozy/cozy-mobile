log = require('./persistent_log')
    prefix: "log sender"
    date: true

SUPPORT_MAIL = 'log-mobile@cozycloud.cc'

module.exports =

    send: ->
        config = window.app.init.config
        subject = "Log from cozy-mobile v#{config.get 'appVersion'}"
        body = """
                #{t('send log please describe problem')}


                ########################
                # #{device.platform}: #{device.version}
                # #{t('send log trace begin')}
                ##

                #{log.getTraces().join('\n')}

                ##
                # #{t('send log trace end')}
                ########################


                #{t('send log please describe problem')}

                """

        query = "subject=#{encodeURI(subject)}&body=#{encodeURI(body)}"

        window.open "mailto:#{SUPPORT_MAIL}?" + query, "_system"
