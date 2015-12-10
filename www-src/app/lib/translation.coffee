Polyglot = require 'node-polyglot'

module.exports = class Translation
    DEFAULT_LANGUAGE: 'en'

    constructor: ->
        @polyglot = new Polyglot()

    setLocale: (locale) ->
        [@language] = locale.value.split '-'
        @_getTranslationsFromFile()

    getTranslate: ->
        @polyglot.t.bind @polyglot

    _getTranslationsFromFile: ->
        translations =
            try
                require '../locales/'+ @language
            catch e
                @language = @DEFAULT_LANGUAGE
                require '../locales/' + @language

        @polyglot.extend translations
