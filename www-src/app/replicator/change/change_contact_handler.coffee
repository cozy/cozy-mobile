log = require('../../lib/persistent_log')
    prefix: "ChangeContactHandler"
    date: true

module.exports = class ChangeContactHandler

    change: (doc) ->
        log.info "change"

        console.log doc

    delete: (doc) ->
        log.info "delete"

        console.log doc
