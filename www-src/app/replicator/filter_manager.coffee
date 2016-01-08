log = require('../lib/persistent_log')
    prefix: "Filter Manager"
    date: true
request = require '../lib/request'

###*
 * FilterManager allows to create a filter specific by device and
 * get this filter to replicate couchdb with it to reduce consumption data.
 *
 * @class FilterManager
###
module.exports = class FilterManager

    ###*
     * Create a FilterManager.
     *
     * @param {String} cozyUrl - it's url
     * @param {String} auth - it's header authentication
    ###
    constructor: (@cozyUrl, @auth) ->

    ###*
     * Create or update a filter for a specific configuration.
     *
     * @param {Boolean} syncContacts - if you want contact synchronization
     * @param {Boolean} syncCalendars - if you want calendar synchronization
     * @param {Boolean} syncNotifs - if you want notification synchronization
     * @param {Function} callback - The callback that handles the response.
    ###
    setFilter: (syncContacts, syncCalendars, syncNotifs, callback) ->
        log.info "setFilter syncContacts: #{syncContacts}, syncCalendars: " +
                "#{syncCalendars}, syncNotifs: #{syncNotifs}"

        options = @_getOptions()
        options.body = @_getConfigFilter syncContacts, syncCalendars, syncNotifs

        request.put options, (err, res, body) =>
            if body?.success or body?._id
                callback true
            else
                log.error err, body
                callback false

    ###*
     * Get filter id for this device.
     *
     * @param {Function} callback - The callback that handles the response.
    ###
    getFilterId: (callback) ->
        log.info "getFilterId"

        request.get @_getOptions(), (err, res, body) =>
            if body?._id?
                callback body._id
            else
                log.error err, body
                callback false

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
     * @return {Object}
    ###
    _getConfigFilter: (syncContacts, syncCalendars, syncNotifs) ->
        compare = "doc.docType === 'file' or doc.docType === 'folder'"
        compare += " or doc.docType === 'contact'" if syncContacts
        compare += " or doc.docType === 'event'" if syncCalendars
        if syncNotifs
            compare += " or (doc.docType === 'notification'"
            compare += " and doc.type === 'temporary')"

        filters:
            config: "function (doc) { return #{compare} }"
