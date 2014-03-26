app = require 'application'
FolderView = require './views/folder'
ConfigView = require './views/config'
FolderCollection = require './collections/files'

module.exports = class Router extends Backbone.Router

    routes:
        'folder/*path'                     : 'folder'
        'config'                          : 'config'

    folder: (path) ->
        if path is null
            app.backButton.attr('href', '#folder/')
            .removeClass('ion-ios7-arrow-back')
            .addClass('ion-home')

        else
            app.backButton.attr('href', '#folder/' + path.split('/')[0..-2])
            .removeClass('ion-home')
            .addClass('ion-ios7-arrow-back')

        @display new FolderView
            collection: FolderCollection.getAtPath path

    config: ->
        @display new ConfigView()

    display: (view) ->
        @mainView.remove() if @mainView
        @mainView = view.render()
        $('#mainContent').append @mainView.$el
