should      = require('chai').should()

# Stubed window global object.
global.window = {}
Utils = require '../../../app/lib/utils'

module.exports = describe 'Utils Test', ->


    # 'setImmediate' should be tested in a browser environment.


    describe 'continueOnError', ->
        logger = error: ->

        continueOnError = Utils.continueOnError(logger)

        it 'should continue on error', (done) ->
            callback = (err) ->
                should.not.exist err
                done()
            continueOnError(callback)('error')

        it 'should transmit arguments on no errors', (done) ->
            callback = (err, arg1, arg2) ->
                should.not.exist err
                arg1.should.equal 'arg1'
                arg2.should.equal 'arg2'
                done()

            continueOnError(callback)(null, 'arg1', 'arg2')

        it 'should use the specified log', (done) ->
            log = error : (msg1, msg2)->

                "#{msg1} #{msg2}".should.equal 'Continue on error: error'

            callback = done

            Utils.continueOnError(log)(callback)('error')

