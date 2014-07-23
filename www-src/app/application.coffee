Replicator = require './replicator/main'
LayoutView = require './views/layout'

module.exports =

    initialize: ->

        window.app = this

        @polyglot = new Polyglot()
        locales = try require 'locales/'+ @locale
        catch e then require 'locales/en'

        @polyglot.extend locales
        window.t = @polyglot.t.bind @polyglot

        Router = require 'router'
        @router = new Router()

        @replicator = new Replicator()
        @layout = new LayoutView()
        $('body').empty().append @layout.render().$el

        @replicator.init (err, config) =>
            console.log err.stack if err
            return alert err.message if err

            Backbone.history.start()

            if config
                @router.navigate 'folder/', trigger: true
            else
                @router.navigate 'login', trigger: true

