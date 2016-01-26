log = require('./persistent_log')
    prefix: "AndroidCalendarHandler"
    date: true
androidCalendarHelper = require '../lib/android_calendar_helper'

module.exports = class AndroidCalendarHandler

    get: (name) ->
        log.info "get"

    create: (doc) ->
        log.info "change"

    update: (doc) ->
        log.info "update"

    delete: (doc) ->
        log.info "delete"
