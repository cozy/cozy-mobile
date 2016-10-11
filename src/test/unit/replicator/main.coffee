helper = require '../../helper/helper'
should = require('chai').should()
Replicator = helper.requireTestFile __filename


global._ = require 'underscore'
global.Backbone = require 'backbone'


module.exports = describe 'Replicator Test', ->


    it 'have default variable', ->
        # arrange

        # act
        replicator = new Replicator()

        # assert
        replicator.get('inSync').should.be.false
        replicator.get('inBackup').should.be.false


    it 'can be init config', ->
        # arrange
        config = "config"
        requestCozy = "requestCozy"
        database = "database"
        fileCacheHandler = "fileCacheHandler"
        replicator = new Replicator()

        # act
        replicator.initConfig config, requestCozy, database, fileCacheHandler

        # assert
        replicator.config.should.equal config
        replicator.requestCozy.should.equal requestCozy
        replicator.database.should.equal database
        replicator.fileCacheHandler.should.equal fileCacheHandler


    it 'can get remote checkpoint', (done) ->
        # arrange
        replicator = new Replicator()
        err = undefined
        res = undefined
        body = last_seq: 1
        replicator.requestCozy =
            request: (options, callback) ->
                callback err, res, body

        # act
        replicator.getRemoteCheckpoint (err, checkpoint) ->

            # assert
            checkpoint.should.be.equal body.last_seq
            done()


    it 'can update index of pouchdb', (done) ->
        # arrange
        replicator = new Replicator()
        replicator.db =
            query: (name, options, cb) ->
                cb()

        # act
        replicator.updateIndex ->

            # assert
            done()


    it 'can update permissions', (done) ->
        # arrange
        replicator = new Replicator()
        database = helper.database.get()
        helper.config.getLoadedWithUrl database, (config) ->
            config.set 'devicePermissions', {}, ->
                replicator.config = config
                replicator.config.hasPermissions().should.be.false
                replicator.requestCozy =
                    request: (options, callback) ->
                        permissions = permissions:config.getDefaultPermissions()
                        callback undefined, undefined, permissions

                # act
                replicator.updatePermissions '', (err) ->

                    # assert
                    replicator.config.hasPermissions().should.be.true
                    done()
        return
