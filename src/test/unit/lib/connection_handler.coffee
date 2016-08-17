should   = require('chai').should()
ConnectionHandler = require '../../../app/lib/connection_handler'
Connection = require '../../../../plugins/' +
    'cordova-plugin-network-information/www/Connection'

global.navigator =
    connection:
        type: 'none'
global.document =
  addEventListener: ->
global.app =
    init:
        currentState: ''


module.exports = describe 'ConnectionHandler Test', ->


    connectionHandler = new ConnectionHandler Connection


    it 'should have connected variable', ->
        connectionHandler.connected.should.be.exist


    it 'should be false when device is offline.', ->
        connectionHandler.isConnected().should.be.false


    it 'should be true when device is online.', ->
        global.navigator.connection.type = 'wifi'
        connectionHandler.isConnected().should.be.true


    it 'should be return true when is on wifi.', ->
        connectionHandler.isWifi().should.be.true
