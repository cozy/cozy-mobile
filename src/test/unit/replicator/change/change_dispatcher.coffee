should = require('chai').should()
mockery = require 'mockery'
""
module.exports = describe 'ChangeDispatcher Test', ->

    config = {}

    before ->
        mockery.enable
            warnOnReplace: false
            warnOnUnregistered: false
            useCleanCache: true

        changeHandlerMock = () ->
            dispatch: (doc, callback) -> callback()

        mockery.registerMock './change_file_handler', changeHandlerMock
        mockery.registerMock './change_event_handler', changeHandlerMock
        mockery.registerMock './change_contact_handler', changeHandlerMock
        mockery.registerMock './change_tag_handler', changeHandlerMock
        @ChangeDispatcher = require \
            '../../../../app/replicator/change/change_dispatcher'

    after ->
        mockery.deregisterAll()
        delete @ChangeDispatcher
        mockery.disable()

    describe '[When all is ok]', ->
        describe 'isDispatched', ->

            it 'return true if this doc is dispatched', ->
                changeDispatcher = new @ChangeDispatcher config
                changeDispatcher.isDispatched(docType: 'file').should.be.true

            it 'return false if this doc isnt dispatched', ->
                changeDispatcher = new @ChangeDispatcher config
                changeDispatcher.isDispatched(docType: 'email').should.be.false

            it 'is case insentivie on docType', ->
                changeDispatcher = new @ChangeDispatcher config
                changeDispatcher.isDispatched(docType: 'File').should.be.true
                changeDispatcher.isDispatched(docType: 'file').should.be.true

            # errors : doc has no doctype

        describe 'dispatch', ->
            # TODO : it 'dispatch to the expected dispatcher', ->

            it 'throw error on unexpected document', (done) ->
                changeDispatcher = new @ChangeDispatcher config
                changeDispatcher.dispatch { docType: 'email' }, (err) ->
                    err.should.exist
                    done()

            it 'is case insentivie on docType', (done) ->
                changeDispatcher = new @ChangeDispatcher config
                changeDispatcher.dispatch { docType: 'File' }, (err) ->
                    should.not.exist err
                    done()

    describe '[All errors]', ->

        it 'handle document without doctype', ->
            changeDispatcher = new @ChangeDispatcher config
            changeDispatcher.isDispatched(noDocType: true).should.be.false
