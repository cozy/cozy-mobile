assert = require 'assert'
mockery = require 'mockery'

module.exports = describe 'FilterManager Test', ->

    defaultId = 42
    cozyUrl = 'cozyUrl'
    deviceName = "my-device"

    before ->
        mockery.enable
            warnOnReplace: false
            warnOnUnregistered: false
            useCleanCache: true

        requestMock =
            put: (options, callback) ->
                if options.auth == "err"
                    callback "err", undefined, undefined
                else if options.auth == "body_empty"
                    callback undefined, undefined, {}
                else if options.auth
                    callback undefined, undefined, _id: defaultId
                else
                    callback undefined, undefined, undefined
            get: (options, callback) ->
                if options.auth == "err"
                    callback "err", undefined, undefined
                else if options.auth == "body_empty"
                    callback undefined, undefined, {}
                else if options.auth
                    callback undefined, undefined, _id: defaultId
                else
                    callback undefined, undefined, undefined

        mockery.registerMock '../lib/request', requestMock
        @FilterManager = require '../../../app/replicator/filter_manager'

    after ->
        mockery.deregisterAll()
        delete @FilterManager
        mockery.disable()

    describe '[When all is ok]', ->

        it "setFilter return true", (done) ->
            filterManager = new @FilterManager cozyUrl, true, deviceName
            filterManager.setFilter true, true, true, (response) ->
                assert.equal response, true
                done()

        it "getFilterName return the filter name", ->
            filterManager = new @FilterManager cozyUrl, true, deviceName
            name = filterManager.getFilterName()
            assert.equal name, "filter-#{deviceName}-config/config"


    describe '[All errors]', ->

        it "When API have an error setFilter return false", (done) ->
            filterManager = new @FilterManager cozyUrl, "err", deviceName
            filterManager.setFilter true, true, true, (id) ->
                assert.equal id, false
                done()

        it "When API don't return _id setFilter return false", (done) ->
            filterManager = new @FilterManager cozyUrl, "body_empty", deviceName
            filterManager.setFilter true, true, true, (id) ->
                assert.equal id, false
                done()
