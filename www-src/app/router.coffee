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
        if path is null
            app.backButton.attr('href', '#folder/')
            .removeClass('ion-ios7-arrow-back')
            .addClass('ion-home')

        else
            app.backButton.attr('href', '#folder/' + path.split('/')[0..-2])
            .removeClass('ion-home')
            .addClass('ion-ios7-arrow-back')

        collection = new FolderCollection [], path: path
        collection.fetch()
        @display new FolderView {collection}

    search: (query) ->
        app.backButton.attr('href', '#folder/')
            .removeClass('ion-ios7-arrow-back')
            .addClass('ion-home')

        collection = new FolderCollection [], query: query
        collection.fetch()
        @display new FolderView {collection}

    login: ->
        @display new ConfigView()

    config: ->
        @display new ConfigRunView()

    display: (view) ->
        @mainView.remove() if @mainView
        @mainView = view.render()
        $('#mainContent').append @mainView.$el
