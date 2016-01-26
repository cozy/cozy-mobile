log = require('../../lib/persistent_log')
    prefix: "ChangeTagHandler"
    date: true

module.exports = class ChangeTagHandler

    change: (doc) ->
        log.info "change"

        console.log doc

    delete: (doc) ->
        log.info "delete"

        console.log doc
