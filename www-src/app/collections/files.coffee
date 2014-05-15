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

            @reset response.rows.map (row) ->
                if row.value.docType is 'File'
                    binary_id = row.value.binary.file.id
                    row.value.incache = app.replicator.binaryInCache binary_id
                return row.value

            options?.onSuccess? this

    fetchAdditional: (options) ->
        folders = @where docType: 'Folder'
        folders.forEach (folder) ->
            app.replicator.folderInCache folder.toJSON(), (err, incache) ->
                return console.log err if err
                folder.set 'incache', incache



