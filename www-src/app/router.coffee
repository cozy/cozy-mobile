app = require 'application'
FolderView = require './views/folder'
LoginView = require './views/login'
ConfigView = require './views/config'
FolderCollection = require './collections/files'

module.exports = class Router extends Backbone.Router

    routes:
        'folder/*path'                    : 'folder'
        'search/*query'                   : 'search'
        'login'                           : 'login'
        'config'                          : 'config'

    folder: (path) ->
        $('#btn-menu, #btn-back').show()
        if path is null
            app.layout.setBackButton '#folder/', 'home'
        else
            backpath = '#folder/' + path.split('/')[0..-2].join '/'
            app.layout.setBackButton backpath, 'ios7-arrow-back'

        cacheOrPrepare path, (err, collection) =>
            return alert err if err
            @display new FolderView {collection}

    search: (query) ->
        $('#btn-menu, #btn-back').show()
        app.layout.setBackButton '#folder/', 'home'

        collection = new FolderCollection [], query: query
        collection.search
            onError: (err) => alert(err)
            onSuccess: =>
                $('#search-input').blur() # close keyboard
                @display new FolderView {collection}

    login: ->
        $('#btn-menu, #btn-back').hide()
        @display new LoginView()

    config: ->
        $('#btn-back').hide()
        @display new ConfigView()

    display: (view) ->
        if @mainView instanceof FolderView and view instanceof FolderView
            direction = if @mainView.isParentOf(view) then 'left' else 'right'
        else
            direction = 'none'

        app.layout.transitionTo view, direction


    # we cache collection fetching for better performance
    #
    bustCache: (path) ->
        path = path.substr 1
        console.log "BUST #{path} #{cache[path]}"
        delete cache[path]
        setTimeout cacheChildren.bind(null, null, [path]), 10

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
            onError: (err) => callback err
            onSuccess: =>
                callback null, collection
                # next tick, do not freeze UI
                setTimeout cacheChildren.bind(null, collection), 10


