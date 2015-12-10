assert      = require 'assert'
should      = require('chai').should()
Translation = require '../../app/lib/translation'

module.exports = describe 'Translation Service Test', ->


    describe 'Before set locale', ->

        notInitialize = new Translation()

        it 'should not have language property before set locale', ->
            notInitialize.should.not.have.property 'language'

        it 'should have polyglot property before set locale', ->
            notInitialize.should.have.property 'polyglot'

        it 'should have english default language', ->
            notInitialize.should.have.property 'DEFAULT_LANGUAGE'
            notInitialize.DEFAULT_LANGUAGE.should.equal 'en'


    describe 'After set locale', ->

        initializeError = new Translation()
        initializeError.setLocale {value: 'af-ZA'}

        it 'should have english language when locale is not supported', ->
            initializeError.should.have.property 'language'
            initializeError.language.should.equal 'en'

        initializeFr = new Translation()
        initializeFr.setLocale {value: 'fr-FR'}

        it 'should have fr language when locale is fr-FR', ->
            initializeFr.should.have.property 'language'
            initializeFr.language.should.equal 'fr'

        t = initializeFr.getTranslate()
        it 'should have a function to translate', ->
            t.should.be.a 'function'

        it 'should be easy to translate', ->
            assert.equal t('error try restart'), 'Essayez de redémarrer l\'application.'
