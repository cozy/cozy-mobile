PouchDB = require 'pouchdb'
Database = require '../../app/lib/database'
options = db: require 'memdown'

module.exports =


    get: (name) ->
        name ?= new Date().toISOString()
        database = new Database options
        if name
            database.replicateDb = new PouchDB "#{name}.replicateDb", options
            database.localDb = new PouchDB "#{name}.localDb", options
        return database
