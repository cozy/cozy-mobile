File = require '../models/file'

PAGE_LENGTH = 20

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
                @trigger 'sync'
                callback err

    # fetch use
    fetch: (callback = ->) ->


        @reset []
        @offset = 0
        # Speed optimisation :
        # First, fetch ordered files ids: all at once;
        # Then, load docs on demand.
        @_fetchPathes @path, (err, results) =>
            @inPathIds = results.rows.map (row) -> return row.id
            @trigger 'fullsync'
            @loadNextPage callback


    loadNextPage: (_callback) ->
        callback = (err, noMoreItems) =>
            @notloaded = false
            @trigger 'sync'
            _callback(err, noMoreItems)

        @_fetchNextPageDocs (err, items) =>
            return callback err if err
            @offset += PAGE_LENGTH

            models = @_rowsToModels items
            noMoreItems = models.length < PAGE_LENGTH

            @add models
            callback err, noMoreItems

    # Fetch all key and id for the specified path
    _fetchPathes: (path, callback) ->
        if path is t 'photos'
            params =
                endkey: if path then ['/' + path] else ['']
                startkey: if path then ['/' + path, {}] else ['', {}]
                descending: true
            view = 'Pictures'
        else
            params =
                startkey: if path then ['/' + path] else ['']
                endkey: if path then ['/' + path, {}] else ['', {}]
            view = 'FilesAndFolder'

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
            if binary_id = doc.binary?.file?.id
                doc.incache = app.replicator.fileInFileSystem doc
                doc.version = app.replicator.fileVersion doc
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
        # console.log "FETCH ADDITIONAL #{toBeCached.length}"
        async.eachSeries toBeCached, (folder, cb) =>
            return cb new Error('cancelled') if @cancelled
            path = folder.wholePath()
            @_fetch path, (err, items) ->
                return cb new Error('cancelled') if @cancelled
                # console.log "CACHING "+ JSON.stringify(path)
                FileAndFolderCollection.cache[path] = items unless err
                app.replicator.folderInFileSystem path, (err, incache) ->
                    return cb new Error('cancelled') if @cancelled
                    console.log err if err
                    folder.set 'incache', incache

                    setTimeout cb, 10 # don't freeze UI

        , (err) =>
            return if @cancelled
            console.log err if err

            # memcache the parent
            path = (@path or '').split('/')[0..-2].join('/')
            # console.log "CACHING "+ path
            @_fetch path, (err, items) =>
                return if @cancelled
                FileAndFolderCollection.cache[path] = items unless err
                @trigger 'fullsync'
