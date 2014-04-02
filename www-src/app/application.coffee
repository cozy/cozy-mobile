Replicator = require './lib/couchbase'

module.exports =

    initialize: ->

        window.app = this

        @polyglot = new Polyglot()
        try
            locales = require 'locales/'+ @locale
        catch e
            locales = require 'locales/en'

        @polyglot.extend locales
        window.t = @polyglot.t.bind @polyglot

        Router = require 'router'
        @router = new Router()

        @backButton = $('#btn-back')

        window.cblite ?= getURL: (cb) -> cb null, 'http://localhost:5984/'
        @replicator = new Replicator()

        # $('#header').on 'click', =>
        #     @replicator.destroyDB (err) =>
        #         $('#header').text err?.message


        @replicator.init (err, config) =>
            return alert err.message if err

            Backbone.history.start()

            if config
                # @replicator.startSync (err) ->
                    # console.log "SYNC OVER", err
                @router.navigate 'folder/', trigger: true
            else
                @router.navigate 'config', trigger: true

