helper = require '../../../helper/helper'
Transformer = helper.requireTestFile __filename


pluginPath = '../../../../../plugins/io.cozy.contacts/www/'
global.ContactName = require "#{pluginPath}ContactName"
global.ContactOrganization = require "#{pluginPath}ContactOrganization"
global.ContactField = require "#{pluginPath}ContactField"
global.ContactAddress = require "#{pluginPath}ContactAddress"
global.window =
    atob: (data) ->
        new Buffer(data, 'base64').toString()


module.exports = describe 'Cozy To Android Contact Transformer Test', ->


    transformer = new Transformer()


    it 'can transform cozy to android', ->
        cozyContact = helper.fixture.getCozyContact()
        cordovaContact = transformer.transform cozyContact
        cordovaContact.should.be.exist


    it 'can transform cozy to android', ->
        cozyContact = helper.fixture.getCozyContact()
        simple = transformer.transform cozyContact
        cozyContact.datapoints.push cozyContact.datapoints[0]  # email
        cozyContact.datapoints.push cozyContact.datapoints[11] # tel
        cozyContact.datapoints.push cozyContact.datapoints[19] # address
        duplicate = transformer.transform cozyContact

        simple.emails.length.should.be.equal duplicate.emails.length
        simple.phoneNumbers.length.should.be.equal duplicate.phoneNumbers.length
        simple.addresses.length.should.be.equal duplicate.addresses.length


    it 'can transform android to cozy', (done) ->
        cordovaContact = require '../../../fixtures/cordova_contact.json'
        transformer.reverseTransform cordovaContact, (err, cozyContact) ->
            cozyContact.should.be.exist
            done()
        return
