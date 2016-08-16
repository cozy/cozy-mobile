should   = require('chai').should()
urlValidator = require '../../../app/lib/url_validator'
url = 'https://test.cozycloud.cc'


module.exports = describe 'urlValidator Test', ->


    describe 'Valid URL', ->

        it 'should accept https url', ->
            urlValidator.validUrl(url).should.be.true

        it 'refuse http url', ->
            urlValidator.validUrl('http://test.cozy').should.be.false


    describe 'Clean URL', ->

        it 'should remove space chars', ->
            urlValidator.cleanUrl("  #{url}  ").should.be.equal url

        it 'should remove / on end url', ->
            urlValidator.cleanUrl("#{url}/").should.be.equal url

        it 'should add https when is not present', ->
            urlValidator.cleanUrl("test.cozycloud.cc").should.be.equal url

        it 'should add .cozycloud.cc when not dash is present', ->
            urlValidator.cleanUrl("https://test").should.be.equal url
