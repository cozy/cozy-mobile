assert          = require 'assert'
async           = require 'async'
PouchDB         = require 'pouchdb'
DesignDocuments = require '../../../app/replicator/design_documents'

module.exports = describe 'DesignDocuments Test', ->

    cozyDB     = new PouchDB 'cozyDB', {db: require 'memdown'}
    internalDB = new PouchDB 'internalDB', {db: require 'memdown'}
    designDocs = new DesignDocuments cozyDB, internalDB

    it 'should be possible to create all design', (done) ->
        designDocs.createOrUpdateAllDesign (error, responses) ->
            async.series [
                (next) -> cozyDB.allDocs {}, (error, response) ->
                    assert.equal 8, response.total_rows
                    next()
                (next) -> internalDB.allDocs {}, (error, response) ->
                    assert.equal 1, response.total_rows
                    next()
            ], done

    it 'should be possible to update one design', (done) ->
        DesignDocuments.PicturesDesignDoc.version++
        designDocs.createOrUpdateAllDesign (error, responses) ->
            updated = responses.filter((doc) -> doc.id != undefined).length
            assert.equal 1, updated
            done()
