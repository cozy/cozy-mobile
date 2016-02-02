log = require('../lib/persistent_log')
    prefix: "Filter Manager"
    date: true
request = require '../lib/request'

###*
 * FilterManager allows to create a filter specific by device and
 * get this filter to replicate couchdb with it to reduce consumption data.
 *
 * @class FilterManager
 * @see https://git.io/vzcCL filters.coffee controller in data-system
###
module.exports = class FilterManager

    ###*
     * Create a FilterManager.
     *
     * @param {String} cozyUrl - it's url
     * @param {String} auth - it's header authentication
     * @param {String} deviceName - it's device name
    ###
    constructor: (@cozyUrl, @auth, @deviceName) ->

    ###*
     * Create or update a filter for a specific configuration.
     *
     * @param {Boolean} syncContacts - if you want contact synchronization
     * @param {Boolean} syncCalendars - if you want calendar synchronization
     * @param {Boolean} syncNotifs - if you want notification synchronization
     * @param {Function} callback - The callback that handles the response.
    ###
    setFilter: (syncContacts, syncCalendars, syncNotifs, callback) ->
        log.info "setFilter syncContacts: #{syncContacts}, syncCalendars: " + \
                "#{syncCalendars}, syncNotifs: #{syncNotifs}"

        options = @_getOptions()
        options.body = @_getConfigFilter syncContacts, syncCalendars, syncNotifs

        request.put options, (err, res, body) ->
            if body?.success or body?._id
                callback()
            else
                err ?= body
                callback err


    ###*
     * Get filter name for this device.
     *
     * @return {String}
    ###
    getFilterName: ->
        log.info "getFilterName"

        "filter-#{@deviceName}-config/config"

    ###*
     * Get options to create a request.
     *
     * @return {Object}
    ###
    _getOptions: ->
        json: true
        auth: @auth
        url: "#{@cozyUrl}/ds-api/filters/config"

    ###*
     * Get configuration to create a filter
     *
     * @param {Boolean} syncContacts - if you want contact synchronization
     * @param {Boolean} syncCalendars - if you want calendar synchronization
     * @param {Boolean} syncNotifs - if you want notification synchronization
     *
     * @return {Object}
    ###
    _getConfigFilter: (syncContacts, syncCalendars, syncNotifs) ->
        compare = "doc.docType === 'file' || doc.docType === 'folder'"
        compare += " || doc.docType === 'contact'" if syncContacts
        if syncCalendars
            compare += " || doc.docType === 'event'"
            compare += " || doc.docType === 'tag'"
        if syncNotifs
            compare += " || (doc.docType === 'notification'"
            compare += " && doc.type === 'temporary')"

        filters:
            config: "function (doc) { return #{compare} }"
