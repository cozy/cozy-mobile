should = require('chai').should()
mockery = require 'mockery'
_ = require 'underscore'

module.exports = describe 'ReplicationLauncher Test', ->

    wantedDocTypes = ['docType1', 'file', 'folder']
    eventHandlersMock =
        on: (event, callback) ->
            @eventHandlers ?= {}
            @eventHandlers[event] = callback

    callEvent = (event, data) ->
        eventHandlersMock.eventHandlers[event](data)


    database =
        replicateDb:
            sync: (remoteDB, options) -> eventHandlersMock
        dbRemote:
            sync: (remoteDB, options) -> eventHandlersMock
    config = get: -> 'launch'
    router = {}
    options = live: false
    filterName = "filterName"

    before ->
        mockery.enable
            warnOnReplace: false
            warnOnUnregistered: false
            useCleanCache: true

        changeDispatcherMock = () ->
            isDispatched: (doc) -> doc.docType in wantedDocTypes

            dispatch: (doc, callback) ->
                if doc.shouldDispatch
                    should.exist 'here'
                    callback()

                else if doc.error
                    callback new Error 'error in dispatch'

                else
                    should.not.exist 'here'

        conflictsHandlerMock = () ->
            handleConflicts: (doc, callback) ->
                if doc.shouldHandle
                    should.exist 'here'
                    callback doc

        connectionHandlerMock = () ->
            isConnected: -> true

        mockery.registerMock './change/change_dispatcher', changeDispatcherMock
        mockery.registerMock './change/conflicts_handler', conflictsHandlerMock
        mockery.registerMock '../lib/connection_handler', connectionHandlerMock
        @ReplicationLauncher = require \
            '../../../app/replicator/replication_launcher'

    after ->
        mockery.deregisterAll()
        delete @ReplicationLauncher
        mockery.disable()

    describe '[When all is ok]', ->
        describe 'initialize replication', ->
            it 'create a sync replication', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start options, ->
                    done()

                callEvent 'complete', {}

            it 'transmit the filter name', (done) ->
                database =
                    replicateDb:
                        sync: (dbRemote, options) ->
                            options.filter.should.eql filterName
                            return eventHandlersMock
                    dbRemote:
                        sync: (remoteDB, options) -> eventHandlersMock

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start options, ->
                    done()

                callEvent 'complete', {}

            it 'set default options', (done) ->
                database =
                    replicateDb:
                        sync: (dbRemote, options) ->
                            options.batch_size.should.eql 20
                            options.batches_limit.should.eql 5
                            return eventHandlersMock
                    dbRemote:
                        sync: (remoteDB, options) -> eventHandlersMock

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start options, ->
                    done()

                callEvent 'complete', {}

            it 'use expected live options', (done) ->
                database =
                    replicateDb:
                        sync: (dbRemote, options) ->
                            options.live.should.be.true
                            options.retry.should.be.true
                            options.heartbeat.should.be.false
                            options.back_off_function.should.be.a 'function'
                            return eventHandlersMock
                    dbRemote:
                        sync: (remoteDB, options) -> eventHandlersMock

                optionsWithLive =
                    live: true
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start optionsWithLive, ->
                    done()

                callEvent 'complete', {}

            it 'transmit the local checkpoint', (done) ->
                localCheckpoint = 120
                database =
                    replicateDb:
                        sync: (dbRemote, options) ->
                            options.push.should.exist
                            options.push.since.should.eql localCheckpoint
                            return eventHandlersMock
                    dbRemote:
                        sync: (remoteDB, options) -> eventHandlersMock

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                optionsWithCheckpoint =
                    live: false
                    localCheckpoint: localCheckpoint
                launcher.start optionsWithCheckpoint, ->
                    done()

                callEvent 'complete', {}


            it 'omit the local checkpoint', (done) ->
                database =
                    replicateDb:
                        sync: (dbRemote, options) ->
                            should.not.exist options.push
                            return eventHandlersMock
                    dbRemote:
                        sync: (remoteDB, options) -> eventHandlersMock

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start options, ->
                    done()

                callEvent 'complete', {}

            it 'transmit the remote checkpoint', (done) ->
                remoteCheckpoint = 120120
                database =
                    replicateDb:
                        sync: (dbRemote, options) ->
                            options.pull.should.exist
                            options.pull.since.should.eql remoteCheckpoint
                            return eventHandlersMock
                    dbRemote:
                        sync: (remoteDB, options) -> eventHandlersMock

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                optionsWithCheckpoint =
                    live: false
                    remoteCheckpoint: remoteCheckpoint
                launcher.start optionsWithCheckpoint, ->
                    done()

                callEvent 'complete', {}

            it 'ommit the remote checkpoint', (done) ->
                database =
                    replicateDb:
                        sync: (dbRemote, options) ->
                            should.not.exist options.pull
                            return eventHandlersMock
                    dbRemote:
                        sync: (remoteDB, options) -> eventHandlersMock

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}, ->
                    done()

                callEvent 'complete', {}

            # event handlers
            it 'call callback on complete event', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}, ->
                    should.exist 'here'
                    done()

                callEvent 'complete', {}
                # test will timeout if broken

            it 'do nothing on paused event', (done) ->
                it 'call callback on complete event', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                filterName, config
                launcher.start {}, ->
                    should.not.exist 'here'
                    done()

                callEvent 'paused', {}
                done()

            it 'do nothing on active event', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}, ->
                    should.not.exist 'here'
                    done()

                callEvent 'active', {}
                done()

            it 'handle mutiples changes event', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}, ->
                    should.not.exist 'here'
                    done()

                callEvent 'change',
                    direction: 'pull'
                    change:
                        docs: [
                            docType: 'docType1'
                        ]

                done()

            it 'do nothing on push change event', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}, ->
                    should.not.exist 'here'
                    done()

                callEvent 'change', direction: 'push'
                done()

        describe 'handle pull changes event', ->
            it 'check conflicts', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}

                callEvent 'change',
                    direction: 'push'
                    change:
                        docs: [
                            docType: 'docType1'
                            shouldHandle: true
                        ]
                done()

            it 'refresh view on file', (done) ->
                router =
                    forceRefresh: () ->
                        should.exist 'here'
                        done()

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}
                callEvent 'change',
                    direction: 'push'
                    change: docs: [ docType: 'file' ]
                done()

            it 'refresh view on folder', (done) ->
                router =
                    forceRefresh: () ->
                        should.exist 'here'
                        done()

                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}
                callEvent 'change',
                    direction: 'push'
                    change: docs: [ docType: 'folder' ]
                done()

            it 'dispatch wanted docs', (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}

                callEvent 'change',
                    direction: 'push'
                    change:
                        docs: [
                            docType: 'docType1'
                            shouldDispatch: true
                        ]

                done()

            it "don't dispatch unwanted docs", (done) ->
                launcher = new @ReplicationLauncher database, router, \
                    filterName, config
                launcher.start {}

                callEvent 'change',
                    direction: 'push'
                    change:
                        docs: [
                            docType: 'unwantedDocType'
                        ]

                done()


    describe '[All errors]', ->

        it 'callback on error event', (done) ->
            launcher = new @ReplicationLauncher database, router, \
                filterName, config
            launcher.start {}, (err) ->
                should.exist err
                done()

            callEvent 'error', {}
            # test will timeout if broken

        # TODO : it 'continue on dispatch error', (done) ->
