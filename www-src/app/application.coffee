Replicator = require './lib/replicator'
LayoutView = require './views/layout'

module.exports =

    initialize: ->

        window.app = this

        window.t = (x) -> x

        @polyglot = new Polyglot()
        try
            locales = require 'locales/'+ @locale
        catch e
            locales = require 'locales/en'

        @polyglot.extend locales
        window.t = @polyglot.t.bind @polyglot

        Router = require 'router'
        @router = new Router()

        @layout = new LayoutView()
        $('body').empty().append @layout.render().$el

        @replicator = new Replicator()
        @replicator.init (err, config) =>
            console.log err.stack if err
            return alert err.message if err

            Backbone.history.start()

            if config
                @router.navigate 'folder/', trigger: true
            else
                @router.navigate 'login', trigger: true

