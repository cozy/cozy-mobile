should = require('chai').should()
FilterManager = require '../../../app/replicator/filter_manager'

module.exports = describe 'FilterManager Test', ->

    deviceName = "my-device"

    getConfig = (deviceName, syncContacts, syncCalendars, cozyNotifications) ->
        deviceName: deviceName
        syncContacts: syncContacts
        syncCalendars: syncCalendars
        cozyNotifications: cozyNotifications
        get: (value) -> @[value]
    getRequestCozy = (err, res, body) ->
        err: err
        res: res
        body: body
        request: (options, callback) -> callback err, res, body
    getDb = (getErr, putErr, existing) ->
        getErr: getErr
        putErr: putErr
        existing: existing
        get: (filterId, callback) ->
            callback getErr, existing
        put: (doc, callback) ->
            callback putErr

    before ->
        @config = getConfig deviceName, true, true, true
        @requestCozy = getRequestCozy false, 2, success: true
        @db = getDb null, null, true
        @filterManager = new FilterManager @config, @requestCozy, @db

    after ->
        delete @filterManager

    describe '[When all is ok]', ->

        it "getFilterName return the filter name", ->
            name = @filterManager.getFilterName()
            name.should.be.equal "filter-#{deviceName}-config/config"

        it "setFilter return true", (done) ->
            @filterManager.setFilter (err, response) ->
                response.should.be.equal true
                done()


    describe '[All errors]', ->

        it "When API have an requestCozy error setFilter return err", (done) ->
            @requestCozy = getRequestCozy 'err', null, null
            @filterManager = new FilterManager @config, @requestCozy, @db

            @filterManager.setFilter (err, response) ->
                err.should.not.to.be.null
                done()

        it "When API have an db error setFilter return err", (done) ->
            @db = getDb null, 'err', true
            @filterManager = new FilterManager @config, @requestCozy, @db

            @filterManager.setFilter (err, response) ->
                err.should.not.to.be.null
                done()
