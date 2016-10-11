helper = require '../../helper/helper'
should   = require('chai').should()
Config = require '../../../app/lib/config'


global._ = require 'underscore'
global.Backbone = require 'backbone'
global.device = helper.fixture.getAndroidDevice()


module.exports = describe 'Config Test', ->


    describe 'Config initialization', (done) ->

        database = helper.database.get()
        config = new Config database

        it 'should have database variable', ->
            config.database.should.be.exist

        it 'should not have config variable', ->
            should.not.exist config.config

        it 'is not loaded', ->
            config.loaded.should.be.false


    describe 'Config load', (done) ->

        database = helper.database.get()
        config = new Config database

        it 'is loaded', (done) ->

            config.load ->
                config.loaded.should.be.true
                should.not.exist database.remoteDB
                done()
            return

        it 'can get variable', ->
            config.get('deviceName').should.exist

        it 'can set variable', (done) ->
            config.set 'deviceName', 'Android-HTC-Passion2', ->
                config.get('deviceName').should.equal 'Android-HTC-Passion2'
                done()
            return


    describe 'Config Cozy Url', ->

        database = helper.database.get()
        config = new Config database

        it 'should not have cozy url', ->
            config.getCozyUrl().should.equal ''

        it 'can set cozy url', (done) ->
            config.load ->
                url = 'https://test.cozycloud.cc'
                config.setCozyUrl url, ->
                    config.getCozyUrl().should.equal url
                    done()
            return


    describe 'Config version', ->

        database = helper.database.get()
        config = new Config database

        it 'should have same version by default', (done) ->
            config.load ->
                config.isNewVersion().should.be.false
                done()
            return

        it 'should be false when not the same version', (done) ->
            config.set 'appVersion', '1.0.0', ->
                config.isNewVersion().should.be.true
                done()
            return

        it 'can upgrade version', (done) ->
            config.updateVersion ->
                config.isNewVersion().should.be.false
                done()
            return
