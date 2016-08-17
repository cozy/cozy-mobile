should = require('chai').should()
Transformer =
    require '../../../../app/replicator/transformer/cozy_to_android_contact'


pluginPath = '../../../../../plugins/io.cozy.contacts/www/'
global.ContactName = require "#{pluginPath}ContactName"
global.ContactOrganization = require "#{pluginPath}ContactOrganization"
global.ContactField = require "#{pluginPath}ContactField"
global.ContactAddress = require "#{pluginPath}ContactAddress"


module.exports = describe 'Cozy To Android Contact Transformer Test', ->

    transformer = new Transformer()

    it 'can transform cozy to android', ->

        cozyContact = require '../../../fixtures/cozy_contact.json'
        cordovaContact = transformer.transform cozyContact
        cordovaContact.should.be.exist

    it 'can transform android to cozy', (done) ->
        cordovaContact = require '../../../fixtures/cordova_contact.json'
        transformer.reverseTransform cordovaContact, (err, cozyContact) ->
            cozyContact.should.be.exist
            done()
        return
