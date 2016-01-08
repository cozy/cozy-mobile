assert = require 'assert'
sinon = require 'sinon'
mockery = require 'mockery'

module.exports = describe 'FilterManager Test', ->

    defaultId = 42
    cozyUrl = 'cozyUrl'

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
            filterManager = new @FilterManager cozyUrl, true
            filterManager.setFilter true, true, true, (response) ->
                assert.equal response, true
                done()

        it "getFilterId return the filter id", (done) ->
            filterManager = new @FilterManager cozyUrl, true
            filterManager.getFilterId (id) ->
                assert.equal id, defaultId
                done()


    describe '[All errors]', ->

        it "When API have an error getFilterId return false", (done) ->
            filterManager = new @FilterManager cozyUrl, "err"
            filterManager.getFilterId (id) ->
                assert.equal id, false
                done()

        it "When API don't return _id getFilterId return false", (done) ->
            filterManager = new @FilterManager cozyUrl, "body_empty"
            filterManager.getFilterId (id) ->
                assert.equal id, false
                done()

        it "When API have an error setFilter return false", (done) ->
            filterManager = new @FilterManager cozyUrl, "err"
            filterManager.setFilter true, true, true, (id) ->
                assert.equal id, false
                done()

        it "When API don't return _id setFilter return false", (done) ->
            filterManager = new @FilterManager cozyUrl, "body_empty"
            filterManager.setFilter true, true, true, (id) ->
                assert.equal id, false
                done()
