async = require 'async'
File = require '../models/file'
DesignDocuments = require '../replicator/design_documents'

PAGE_LENGTH = 20

log = require('../lib/persistent_log')
    prefix: "files collections"
    date: true

module.exports = class FileAndFolderCollection extends Backbone.Collection
    model: File

    @cache: {}

    initialize: (models, options) ->
        @path = options.path
        @query = options.query
        @notloaded = true

    isSearch: -> @path is undefined

    # search use temporary view
    search: (callback) ->
        params =
            query: @query
            fields: ['name']
            include_docs: true

        app.replicator.db.search params, (err, items) =>
            @slowReset items, (err) =>
                @notloaded = false
                @allPagesLoaded = true
                @trigger 'sync'
                callback err

    # fetch use
    fetch: (callback = ->) ->
        @offset = 0
        # Speed optimisation :
        # First, fetch ordered files ids: all at once;
        # Then, load docs on demand.
        @_fetchPathes @path, (err, results) =>
            @inPathIds = results.rows.map (row) -> return row.id
            @loadNextPage callback
            @trigger 'fullsync'


    loadNextPage: (_callback) ->
        callback = (err, noMoreItems) =>
            @notloaded = false
            @trigger 'sync'
            _callback(err, noMoreItems)

        @_fetchNextPageDocs (err, items) =>
            return callback err if err

            models = @_rowsToModels items
            @allPagesLoaded = models.length < PAGE_LENGTH

            if @offset is 0
                @reset models
            else
                @add models

            @offset += PAGE_LENGTH

            callback err, @allPagesLoaded

    # Fetch all key and id for the specified path
    _fetchPathes: (path, callback) ->
        if path is t 'photos'
            params =
                endkey: if path then ['/' + path] else ['']
                startkey: if path then ['/' + path, {}] else ['', {}]
                descending: true
            view = DesignDocuments.PICTURES
        else
            params =
                startkey: if path then ['/' + path] else ['']
                endkey: if path then ['/' + path, {}] else ['', {}]
            view = DesignDocuments.FILES_AND_FOLDER

        app.replicator.db.query view, params, callback

    # Fetch the docs for the next files.
    _fetchNextPageDocs: (callback) ->
        ids = @inPathIds.slice @offset, @offset + PAGE_LENGTH

        params =
            keys: ids
            include_docs: true

        app.replicator.db.allDocs params, callback

    _rowsToModels: (results) ->
        return results.rows.map (row) ->
            doc = row.doc
            if doc.docType.toLowerCase() is 'file'
                if doc.binary?.file?.id
                    doc.incache = app.replicator.fileInFileSystem doc
                    doc.version = app.replicator.fileVersion doc

            else if doc.docType.toLowerCase() is 'folder'
                # TODO ASYNC !  doc.incache = app.replicator.folderInFileSystem doc
                doc.incache = false

            return doc

    slowReset: (results, callback) ->
        models = @_rowsToModels results

        #immediately reset 10 models (fill view)
        @reset models.slice 0, 10

        if models.length < 10
            return callback null

        i = 0
        # then add 10 models every 10 ms (dont freeze UI)
        do nonBlockingAdd = =>
            if i*10 > models.length
                @nextAdd = null
                return callback null

            i++
            @add models.slice i*10, (i+1)*10
            @nextAdd = setTimeout nonBlockingAdd, 10

    remove: ->
        super
        @clearTimeout @nextAdd


    cancelFetchAdditional: ->
        @cancelled = true
    # ut my parent & children folder in cache
    #
    fetchAdditional: ->
        # reset cache
        FileAndFolderCollection.cache = {}

        # memcache children, check if they are in filesystem
        toBeCached = @filter (model) ->
            model.get('docType')?.toLowerCase() is 'folder'
        async.eachSeries toBeCached, (folder, cb) =>
            return cb new Error('cancelled') if @cancelled
            path = folder.wholePath()
            @_fetch path, (err, items) ->
                return cb new Error('cancelled') if @cancelled
                FileAndFolderCollection.cache[path] = items unless err
                app.replicator.folderInFileSystem path, (err, incache) ->
                    return cb new Error('cancelled') if @cancelled
                    log.error err if err
                    folder.set 'incache', incache

                    setImmediate cb # don't freeze UI

        , (err) =>
            return if @cancelled
            log.error err if err

            # memcache the parent
            path = (@path or '').split('/')[0..-2].join('/')
            @_fetch path, (err, items) =>
                return if @cancelled
                FileAndFolderCollection.cache[path] = items unless err
                @trigger 'fullsync'
