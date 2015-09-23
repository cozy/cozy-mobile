should = require('chai').Should()
expect = require('chai').expect

# Hack to plugin dependency.
global.ContactAddress = require '../../plugins/io.cozy.contacts/www/ContactAddress'
global.ContactField = require '../../plugins/io.cozy.contacts/www/ContactField'
global.ContactFieldType = require '../../plugins/io.cozy.contacts/www/ContactFieldType'
global.ContactName = require '../../plugins/io.cozy.contacts/www/ContactName'
global.ContactOrganization = require '../../plugins/io.cozy.contacts/www/ContactOrganization'


Contact = require '../app/models/contact'

# Helpers
structuredToFlat = (t) ->
    t = t.filter (part) -> return part? and part isnt ''
    return t.join ', '

adrArrayToString = (value) ->
    value = value or []

    streetPart = structuredToFlat value[0..2]
    countryPart = structuredToFlat value[3..6]

    flat = streetPart
    flat += '\n' + countryPart if countryPart isnt ''
    return flat

datapoints2String = (datapoints) ->
    # convert Datapoints to strings
    stringDps = datapoints.map (datapoint) ->
        s = "name:#{datapoint.name}, type:#{datapoint.type}, value: "

        if datapoint.name is 'adr'
            s += adrArrayToString datapoint.value
        else if datapoint.name is 'tel'
            s += datapoint.value?.replace /[^\d+]/g, ''
        else
            s += datapoint.value

    # sort them.
    stringDps.sort()

    return "datapoints: " + stringDps.join ', '

describe 'Unit tests', ->
    describe 'n2ContactName', ->
        it 'typical name', ->
            Contact._n2ContactName('Michael;John;;;').should.eql(
                new ContactName('Michael John', 'Michael', 'John'))

        it 'empty name parts', ->
            Contact._n2ContactName(';;;;;').should.eql new ContactName()

        it 'invalide name parts count', ->
            Contact._n2ContactName('Michael;John').should.eql(
                new ContactName('Michael John', 'Michael', 'John'))

        it 'empty name', ->
            Contact._n2ContactName('').should.eql new ContactName()

        it 'no name', ->
            expect(Contact._n2ContactName()).to.be.undefined

    describe 'adr2ContactAddress', ->
        it 'one line address', ->
            Contact._adr2ContactAddress
                type: "home"
                value: ["","","6 rue Machin Chose\n75010 Paris","","",""]
            .should.eql new ContactAddress undefined, "home"
            ,"6 rue Machin Chose\n75010 Paris"
            , "6 rue Machin Chose\n75010 Paris"

        it 'typical address', ->
            Contact._adr2ContactAddress
                type: "home"
                value: ["","","6 rue Machin Chose", "Paris", "", "75010", ""]
            .should.eql new ContactAddress undefined, "home"
            , "6 rue Machin Chose\nParis, 75010"
            , "6 rue Machin Chose", "Paris", "", "75010", ""

        it 'missing parts', ->
            Contact._adr2ContactAddress
                type: "home"
                value: ["","","6 rue Machin Chose\n75010 Paris"]
            .should.eql new ContactAddress undefined, "home"
            ,"6 rue Machin Chose\n75010 Paris"
            , "6 rue Machin Chose\n75010 Paris"
        it 'zealous address', ->
            Contact._adr2ContactAddress
                type: "home"
                value: ["POB 999", "Northville", "80 Maple Road"
                    , "Danbury", "CT", "06810", "USA"]
            .should.eql new ContactAddress undefined, "home"
            , "POB 999, Northville, 80 Maple Road\nDanbury, CT, 06810, USA"
            , "POB 999, Northville, 80 Maple Road"
            , "Danbury", "CT", "06810", "USA"


describe 'Convert Cozy contact to cordova tests', ->
    describe 'Cozy2Cordova', ->
        cozyContact = require './fixtures/cozy_contact.json'
        expected = require './fixtures/cordova_contact.json'
        obtained = Contact._cozy2CordovaOptions cozyContact

        it "name", ->
            obtained.name.should.eql expected.name
        it "displayName", ->
            obtained.displayName.should.eql expected.displayName
        it "organizations", ->
            obtained.organizations.should.eql expected.organizations
        it "birthday", ->
            obtained.birthday.should.eql expected.birthday
        it "urls", ->
            obtained.urls.should.eql expected.urls
        it "note", ->
            obtained.note.should.equal expected.note
        it "categories", ->
            obtained.categories.should.eql expected.categories
        it "sourceId", ->
            obtained.sourceId.should.equal expected.sourceId
        it "sync2", ->
            obtained.sync2.should.equal expected.sync2
        it "phoneNumbers", ->
            obtained.phoneNumbers.should.eql expected.phoneNumbers
        it "emails", ->
            obtained.emails.should.eql expected.emails
        it "addresses", ->
            obtained.addresses.should.eql expected.addresses
        it "ims", ->
            obtained.ims.should.eql expected.ims
        it "urls", ->
            obtained.urls.should.eql expected.urls
        it "about", ->
            obtained.about.should.eql expected.about
        it "relation", ->
            obtained.relations.should.eql expected.relations

        # TODO : missing nickname field.


describe 'Convert Cordova contact to Cozy tests', ->
    describe 'Cordova2Cozy', ->
        cordovaContact = require './fixtures/cordova_contact.json' # TODO !
        expected = require './fixtures/cozy_contact.json'
        Contact.cordova2Cozy cordovaContact, (err, obtained) ->
            it "fn", ->
                obtained.fn.should.eql expected.fn
            # it "_id", ->
            #     obtained._id.should.eql expected._id
            # it "id", ->
            #     obtained.id.should.eql expected.id
            # it "_rev", ->
                obtained._rev.should.eql expected._rev
            it "n", ->
                obtained.n.should.eql expected.n
            it "bday", ->
                obtained.bday.should.eql expected.bday
            it "note", ->
                obtained.note.should.eql expected.note
            # url field deprecated with contact-2.0
            # it "url", ->
            #     obtained.url.should.eql expected.url
            it "org", ->
                obtained.org.should.eql expected.org
            it "title", ->
                obtained.title.should.eql expected.title
            it "datapoints", ->
                expect(datapoints2String(obtained.datapoints))
                    .to.equal datapoints2String expected.datapoints

            # TODO: missing nickname
            # TODO : missing department
