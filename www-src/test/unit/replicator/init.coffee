async  = require 'async'
should = require('chai').should()

global._ = require 'underscore'
global.Backbone = require 'backbone'
global.XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest

require 'backbone.statemachine'

module.exports = describe 'Init Test', ->
    Init = require '../../../app/init'

    ['mTest1', 'mTest2', 'mTetst3',
     'smTest1', 'smTest2', 'smTetst3',
     'fTest1', 'aTest2', 'sTetst3'].forEach (state) ->
         Init.prototype.states[state] = {}

    Init.prototype.transitions.mTest1 = 'next1': 'mTest2'
    Init.prototype.transitions.mTest2 = 'next2': 'mTest3'

    Init.prototype.transitions.smTest1 = 'next1': 'smTest2'
    Init.prototype.transitions.smTest2 = 'next2': 'smTest3'

    Init.prototype.transitions.fTest1 = 'next1': 'aTest2'
    Init.prototype.transitions.aTest2 = 'next2': 'sTest3'


    # Tools
    describe 'passUnlessInMigration', ->
        init = new Init()

        init.startStateMachine()
        # Stub : init after migrationState default initialization.
        init.migrationStates = 'mTest1': true, 'mTest3': true

        it 'should return true to pass', (done) ->
            init.toState 'mTest2'
            init.passUnlessInMigration('next2').should.be.true
            done()

        it 'should trigger event while passing', (done) ->
            init.toState 'mTest2'
            init.passUnlessInMigration 'next2'
            init.currentState.should.eql 'mTest3'
            done()

        it 'should do same with service migration', (done) ->

            init.toState 'smTest2'
            init.passUnlessInMigration('next2').should.be.true

            init.toState 'smTest2'
            init.passUnlessInMigration 'next2'
            init.currentState.should.eql 'smTest3'

            done()

        it 'should return false when included in migration', (done) ->
            init.toState 'mTest1'
            init.passUnlessInMigration('next1').should.be.false
            done()

        it 'should not trigger when included in migration', (done) ->
            init.toState 'mTest1'
            init.passUnlessInMigration('next1')
            init.currentState.should.be.equal 'mTest1'
            done()

        it 'should return false outside of migrations', (done) ->
            init.toState 'sTest3'
            init.passUnlessInMigration('next3').should.be.false
            done()

        it 'should not trigger outside of migration', (done) ->
            init.toState 'sTest3'
            init.passUnlessInMigration('next3')
            init.currentState.should.be.equal 'sTest3'
            done()

    describe 'initMigration', ->


        Init.prototype.migrations =
            "0.1.1": states: ['mTest1']
            "0.1.0": states: []
            "0.0.3": states: ['mTest1', 'mTest3']
            "0.0.2": states: ['mTest2']


        it 'should collect all states', (done) ->
            init = new Init()
            init.startStateMachine()
            init.initMigrations undefined
            init.migrationStates.should.eql
                'mTest1': true
                'mTest2': true
                'mTest3': true
            done()

        it 'should collect states down to old version', (done) ->
            init = new Init()
            init.startStateMachine()
            init.initMigrations "0.1.0"
            init.migrationStates.should.eql
                'mTest1': true
            done()

        it 'should collect states down to old version (bis)', (done) ->
            init = new Init()
            init.startStateMachine()
            init.initMigrations "0.0.2"
            init.migrationStates.should.eql
                'mTest1': true
                'mTest3': true
            done()


