File = require '../models/file'

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
                callback err

    # fetch use
    fetch: (_callback = ->) ->
        callback = (err) =>
            @notloaded = false
            @trigger 'sync'
            _callback(err)

        cacheKey = if @path is null then '' else @path
        # console.log "IN CACHE " + JSON.stringify(cacheKey)
        if cacheKey of FileAndFolderCollection.cache
            items = FileAndFolderCollection.cache[cacheKey]
            return @slowReset items, (err) =>
                @fetchAdditional() unless err
                callback err

        console.log "CACHE MISS " + cacheKey


        if @path is app.replicator.config.get('deviceName')
            params =
                endkey: if @path then ['/' + @path] else ['']
                startkey: if @path then ['/' + @path, {}] else ['', {}]
                include_docs: true
                descending: true

            app.replicator.db.query 'Pictures', params, (err, items) =>
                return callback err if err
                @slowReset items, (err) =>
                    @fetchAdditional() unless err
                    callback err

        else

            @_fetch @path, (err, items) =>
                return callback err if err
                @slowReset items, (err) =>
                    @fetchAdditional() unless err
                    callback err


    _fetch: (path, callback) ->
        params =
            startkey: if path then ['/' + path] else ['']
            endkey: if path then ['/' + path, {}] else ['', {}]
            include_docs: true

        app.replicator.db.query 'FilesAndFolder', params, callback

    slowReset: (results, callback) ->
        models = results.rows.map (row) ->
            doc = row.doc
            if binary_id = doc.binary?.file?.id
                doc.incache = app.replicator.fileInFileSystem doc
                doc.version = app.replicator.fileVersion doc
            return doc

        #immediately reset 10 models (fill view)
        @reset models.slice 0, 10
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