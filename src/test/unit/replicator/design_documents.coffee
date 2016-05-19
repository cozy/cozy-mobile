async           = require 'async'
PouchDB         = require 'pouchdb'
should          = require('chai').should()
DesignDocuments = require '../../../app/replicator/design_documents'

module.exports = describe 'DesignDocuments Test', ->

    cozyDB     = new PouchDB 'cozyDB', {db: require 'memdown'}
    internalDB = new PouchDB 'internalDB', {db: require 'memdown'}
    designDocs = new DesignDocuments cozyDB, internalDB

    it 'should be possible to create all design', (done) ->
        designDocs.createOrUpdateAllDesign (error, responses) ->
            async.series [
                (next) -> cozyDB.allDocs {}, (error, response) ->
                    response.total_rows.should.be.equal 7
                    next()
                (next) -> internalDB.allDocs {}, (error, response) ->
                    response.total_rows.should.be.equal 2
                    next()
            ], done

    it 'should be possible to update one design', (done) ->
        DesignDocuments.PicturesDesignDoc.version++
        designDocs.createOrUpdateAllDesign (error, responses) ->
            updated = responses.filter((doc) -> doc.id != undefined).length
            updated.should.be.equal 1
            done()
