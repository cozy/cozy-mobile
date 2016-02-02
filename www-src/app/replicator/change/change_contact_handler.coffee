log = require('../../lib/persistent_log')
    prefix: "ChangeContactHandler"
    date: true

module.exports = class ChangeContactHandler

    dispatch: (doc, callback) ->
        log.info "dispatch"

        console.log doc
        callback()

