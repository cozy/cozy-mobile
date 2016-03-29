Polyglot = require 'node-polyglot'
log = require('./persistent_log')
    prefix: "Translation"
    date: true

module.exports = class Translation
    DEFAULT_LANGUAGE: 'en'

    constructor: ->
        @polyglot = new Polyglot()

    setLocale: (locale) ->
        log.debug "setLocale: #{locale.value}"

        [@language] = locale.value.split '-'
        translations =
            try
                require '../locales/'+ @language
            catch e
                @language = @DEFAULT_LANGUAGE
                require '../locales/' + @language

        @polyglot.extend translations

    getTranslate: ->
        @polyglot.t.bind @polyglot

    setDeviceLocale: (callback) ->
        log.debug "setDeviceLocale"

        # Monkey patch for browser debugging
        if window.isBrowserDebugging
            window.navigator = window.navigator or {}
            window.navigator.globalization =
                window.navigator.globalization or {}
            window.navigator.globalization.getPreferredLanguage = (cb) =>
                cb value: @DEFAULT_LANGUAGE

        # Use the device's locale until we get the config document.
        navigator.globalization.getPreferredLanguage (properties) =>
            @setLocale(properties)
            window.t = @getTranslate()
            callback()
