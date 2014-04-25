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

        cacheOrPrepare path, (err, collection) =>
            return alert err if err
            app.menu.close()
            @display new FolderView {collection}

    search: (query) ->
        $('#btn-menu, #btn-back').show()
        app.backButton.attr('href', '#folder/')
            .removeClass('ion-ios7-arrow-back')
            .addClass('ion-home')

        collection = new FolderCollection [], query: query
        collection.fetch
            onError: (err) => alert(err)
            onSuccess: =>
                app.menu.close()
                $('#search-input').blur() # close keyboard
                @display new FolderView {collection}

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
                @mainView.remove()
                @mainView = view

        else
            @mainView.remove() if @mainView
            @mainView = view.render()
            $('#mainContent').append @mainView.$el



    # we cache collection fetching for better performance
    cache = {}
    timeouts = {}
    cacheChildren = (collection, array) ->
        # first run, empty cache and transform collection in array of path
        if collection
            cache = {}
            array = collection.filter (model) ->
                model.get('docType')?.toLowerCase?() is 'folder'
            array = array.map (model) ->
                (model.get('path') + '/' + model.get('name')).substr 1

            parent = (collection.path or '/fake').split('/')[0..-2].join('/')
            console.log "PARENT = ", parent
            array.push parent

        # first & next runs
        if array.length is 0
            return # all done

        # shift, prefetch, next
        path = array.shift()
        collection = new FolderCollection [], path: path
        collection.fetch
            onError: (err) =>
                # don't handle err
                console.log err
                cacheChildren null, array
            onSuccess: =>
                cache[path] = collection
                cacheChildren null, array

    cacheOrPrepare = (path, callback) ->

        path = "" unless path

        if incache = cache[path]
            setTimeout cacheChildren.bind(null, incache), 10
            return callback null, incache

        console.log 'CACHE MISS'

        collection = new FolderCollection [], path: path
        collection.fetch
            onError: (err) => cb err
            onSuccess: =>
                callback null, collection
                # next tick, do not freeze UI
                setTimeout cacheChildren.bind(null, collection), 10


