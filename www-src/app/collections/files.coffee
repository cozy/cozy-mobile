File = require '../models/file'

module.exports = class FileAndFolderCollection extends Backbone.Collection
    model: File
    parse: (couchdb_result) -> couchdb_result.rows.map (row) -> row.value

FileAndFolderCollection.getAtPath = (path) ->
    if not path then path = '' else path = '/' + path
    col = new FileAndFolderCollection()
    col.url = app.replicator.db + '/_design/folder/_view/byFolder?key=%22' + path + '%22'
    col.fetch(remove: false)
    col.url = app.replicator.db + '/_design/file/_view/byFolder?key=%22' + path + '%22'
    col.fetch(remove: false)
    console.log "col was fetched", col.url
    return col
