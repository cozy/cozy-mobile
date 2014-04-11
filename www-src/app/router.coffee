app = require 'application'
FolderView = require './views/folder'
ConfigView = require './views/config'
ConfigRunView = require './views/config_run'
FolderCollection = require './collections/files'

module.exports = class Router extends Backbone.Router

    routes:
        'folder/*path'                    : 'folder'
        'search/*query'                   : 'search'
        'config'                          : 'login'
        'configrun'                       : 'config'

    folder: (path) ->
        $('#btn-menu, #btn-back').show()
        if path is null
            app.backButton.attr('href', '#folder/')
            .removeClass('ion-ios7-arrow-back')
            .addClass('ion-home')

        else
            app.backButton.attr('href', '#folder/' + path.split('/')[0..-2])
            .removeClass('ion-home')
            .addClass('ion-ios7-arrow-back')

        collection = new FolderCollection [], path: path
        collection.fetch
            onError: (err) => alert(err)
            onSuccess: => @display new FolderView {collection}

    search: (query) ->
        $('#btn-menu, #btn-back').show()
        app.backButton.attr('href', '#folder/')
            .removeClass('ion-ios7-arrow-back')
            .addClass('ion-home')

        collection = new FolderCollection [], query: query
        collection.fetch
            onError: (err) => alert(err)
            onSuccess: => @display new FolderView {collection}

    login: ->
        $('#btn-menu, #btn-back').hide()
        @display new ConfigView()

    config: ->
        $('#btn-back').hide()
        @display new ConfigRunView()

    display: (view) ->
        if @mainView instanceof FolderView and view instanceof FolderView

            isBack = @mainView.isParentOf view

            # sliding transition
            next = view.render().$el.addClass if isBack then 'sliding-next' else 'sliding-prev'
            $('#mainContent').append next
            next.width() # force reflow

            @mainView.$el.addClass if isBack then 'sliding-prev' else 'sliding-next'
            next.removeClass if isBack then 'sliding-next' else 'sliding-prev'
            transitionend = 'webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend'
            next.one transitionend, =>
                console.log "trend"
                @mainView.remove()
                @mainView = view

        else
            console.log "DOH"
            @mainView.remove() if @mainView
            @mainView = view.render()
            $('#mainContent').append @mainView.$el
