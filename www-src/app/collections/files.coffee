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
        if atype < btype then return 1
        else if btype > atype then return -1
        else if aname < bname then return -1
        else if aname > bname then return 1
        else return 0

    fetch: ->
        map = options = null
        if @query
            options = {}
            regexp = new RegExp @query, 'i'
            map = (doc, emit) ->
                if doc.docType in ['Folder', 'File'] and regexp.test doc.name
                    emit doc._id, doc
        else
            options = key: if @path then '/' + @path else ''
            map = (doc, emit) ->
                if doc.docType in ['Folder', 'File']
                    emit doc.path, doc

        app.replicator.db.query map, options, (err, response) =>
            docs = response.rows.map (row) -> row.value
            for doc in docs when doc.docType is 'File'
                isDoc = (entry) -> entry.name is doc.binary.file.id
                if app.replicator.cache.some isDoc
                    doc.incache = true

            @reset docs
