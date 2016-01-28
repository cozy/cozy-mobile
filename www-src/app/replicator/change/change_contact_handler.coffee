log = require('../../lib/persistent_log')
    prefix: "ChangeContactHandler"
    date: true

module.exports = class ChangeContactHandler

    change: (doc, callback) ->
        log.info "change"

        console.log doc
        callback()

    delete: (doc, callback) ->
        log.info "delete"

        console.log doc
        callback()

