File = require '../models/file'

module.exports = class FileAndFolderCollection extends Backbone.Collection
    model: File

    initialize: (models, options) ->
        @path = options.path
        @query = options.query

    comparator: (a, b) ->
        atype = a.get('docType').toLowerCase()
        btype = b.get('docType').toLowerCase()
        aname = a.get('name').toLowerCase()
        bname = b.get('name').toLowerCase()
        return out = if atype < btype then 1
        else   if atype > btype then -1
        else   if aname > bname then 2
        else   if aname < bname then -2
        else 0


    fetch: (options) ->
        map = params = null
        if @query
            params = {}
            regexp = new RegExp @query, 'i'
            map = (doc, emit) ->
                if doc.docType in ['Folder', 'File'] and regexp.test doc.name
                    emit doc._id, doc
        else
            params = key: if @path then '/' + @path else ''
            map = (doc, emit) ->
                if doc.docType in ['Folder', 'File']
                    emit doc.path, doc

        app.replicator.db.query map, params, (err, response) =>
            return options?.onError? err if err

            docs = response.rows.map (row) ->
                doc = row.value
                isDoc = (entry) -> entry.name is doc.binary.file.id
                if doc.docType is 'File' and app.replicator.cache.some isDoc
                    doc.incache = true
                return doc

            @reset docs

            options?.onSuccess? this
