log = require('../../lib/persistent_log')
    prefix: "ChangeContactHandler"
    date: true



###*
 * ChangeContactHandler Can create, update or delete an contact on your device
 *
###
module.exports = class ChangeContactHandler

    dispatch: (doc, callback) ->
        log.info "dispatch"

        console.log doc
        callback()

