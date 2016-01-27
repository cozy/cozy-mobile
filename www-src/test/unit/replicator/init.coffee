assert          = require 'assert'
async           = require 'async'
PouchDB         = require 'pouchdb'
Init = require '../../../app/replicator/init'

module.exports = describe 'Init Test', ->

    # cozyDB     = new PouchDB 'cozyDB', {db: require 'memdown'}
    # internalDB = new PouchDB 'internalDB', {db: require 'memdown'}
    # designDocs = new DesignDocuments cozyDB, internalDB

    # Tools
    describe 'passUnlessInMigration', ->
        init = new Init()

        init.migrationStates = 'mTest1': true, 'mTest3': true
        ['mTest1', 'mTest2', 'mTetst3',
         'smTest1', 'smTest2', 'smTetst3',
         'fTest1', 'aTest2', 'sTetst3'].forEach (state) ->
            init.states[state] = {}

        init.transitions.mTest1 = 'next1': 'mTest2'
        init.transitions.mTest2 = 'next2': 'mTest3'

        init.transitions.smTest1 = 'next1': 'smTest2'
        init.transitions.smTest2 = 'next2': 'smTest3'

        init.transitions.fTest1 = 'next1': 'aTest2'
        init.transitions.aTest2 = 'next2': 'sTest3'

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

        it 'should return false if in migration', (done) ->
            init.toState 'mTest1'
            init.passUnlessInMigration('next1').should.be.false
            done()

        it 'should not trigger if in migration', (done) ->
            init.toState 'mTest1'
            init.passUnlessInMigration('next1')
            init.currentState.should.be 'mTest1'
            done()

        it 'should return false outside of migrations', (done) ->
            init.toState 'sTest3'
            init.passUnlessInMigration('next3').should.be.false
            done()

        it 'should not trigger outside of migration', (done) ->
            init.toState 'sTest3'
            init.passUnlessInMigration('next3')
            init.currentState.should.be 'sTest3'
            done()

    describe 'initMigration', ->
        init = new Init()

        init.migrations =
            "0.1.1": states: ['mTest1']
            "0.1.0": states: []
            "0.0.3": states: ['mTest1', 'mTest3']
            "0.0.2": states: ['mTest2']


        it 'should collect all states', (done) ->
            init.initMigration undefined
            init.migrationStates.should.eql
                'mTest1': true
                'mTest2': true
                'mTest3': true
