should   = require('chai').should()
Database = require '../../../app/lib/database'

options = db: require 'memdown'
url = 'cozyUrlForTest'

module.exports = describe 'Database Service Test', ->

    describe 'constants', ->

        it 'should get replicate database name', ->
            Database.REPLICATE_DB.should.be.equal 'cozy-files.db'

        it 'should get local database name', ->
            Database.LOCAL_DB.should.be.equal 'cozy-photos.db'

    describe 'Create databases', ->

        database = new Database options

        it 'must have replicate database', ->
            database.replicateDb.should.be.an.Object

        it 'must have local database', ->
            database.localDb.should.be.an.Object

        it 'must not have remote database', ->
            (database.remoteDb is undefined).should.be.true

        it 'must have remote database after init it', ->
            database.setRemoteDatabase url
            database.remoteDb.should.be.an.Object
