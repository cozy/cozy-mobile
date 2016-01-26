log = require('../lib/persistent_log')
    prefix: "ChangeEventHandler"
    date: true

module.exports = class ChangeEventHandler

    change: (doc) ->
        log.info "change"

        if doc._rev.split('-')[0] is 1
            @create doc
        else
            @update doc

    create: (doc) ->
        log.info "create"

        console.log doc

    update: (doc) ->
        log.info "update"

        console.log doc

    delete: (doc) ->
        log.info "delete"

        console.log doc
