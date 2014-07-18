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


    # search use temporary view
    search: (options) ->
        callback = @resetFromPouch.bind this, options
        params =
            query: @query
            fields: ['name']
            include_docs: true

        app.replicator.db.search params, callback

    # fetch use
    fetch: (options) ->
        params =
            key: if @path then '/' + @path else ''
            include_docs: true

        callback = @resetFromPouch.bind this, options
        app.replicator.db.query 'FilesAndFolder', params, callback



    resetFromPouch: (options, err, response) =>
        return options?.onError? err if err

        @reset response.rows.map (row) ->
            if row.doc.docType is 'File'
                binary_id = row.doc.binary.file.id
                row.doc.incache = app.replicator.binaryInCache binary_id
            return row.doc

        options?.onSuccess? this

    fetchAdditional: (options) ->
        folders = @where docType: 'Folder'
        folders.forEach (folder) ->
            app.replicator.folderInCache folder.toJSON(), (err, incache) ->
                return console.log err if err
                folder.set 'incache', incache



