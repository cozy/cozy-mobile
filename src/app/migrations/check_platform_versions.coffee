semver = require 'semver'
log = require('../lib/persistent_log')
    prefix: "CheckPlatformVersions"
    date: true


PLATFORM_VERSIONS =
    'proxy': '>=2.1.11'
    'data-system': '>=2.1.8'


module.exports =

    checkPlatformVersions: (callback) ->
        log.debug 'checkPlatformVersions'

        config = app.init.config
        requestCozy = app.init.requestCozy
        options =
            method: 'get'
            url: "#{config.get 'cozyURL'}/versions"

        requestCozy.request options, (err, response, body) ->
            return callback err if err # TODO i18n ?

            for item in body
                [s, app, version] = item.match /([^:]+): ([\d\.]+)/
                if app of PLATFORM_VERSIONS
                    unless semver.satisfies(version, PLATFORM_VERSIONS[app])
                        msg = t 'error need min %version for %app'
                        msg = msg.replace '%app', app
                        msg = msg.replace '%version', PLATFORM_VERSIONS[app]
                        return callback new Error msg

            # Everything fine
            callback()
