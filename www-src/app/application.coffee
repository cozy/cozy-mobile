Replicator = require './replicator/main'
LayoutView = require './views/layout'

module.exports =

    initialize: ->

        window.app = this

        navigator.globalization.getPreferredLanguage (properties) =>
            [@locale] = properties.value.split '-'

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
                if err
                    console.log err, err.stack
                    return alert err.message or err

                Backbone.history.start()

                if config.remote
                    @router.navigate 'folder/', trigger: true
                    @router.once 'collectionfetched', =>
                        app.replicator.startRealtime()

                        app.replicator.backup()
                        document.addEventListener "resume", =>
                            console.log "RESUME EVENT"
                            if app.backFromOpen
                                app.backFromOpen = false
                            else
                                app.replicator.backup()
                        , false
                else
                    @router.navigate 'login', trigger: true

