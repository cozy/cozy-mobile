createOrUpdateDesign = (db, design, callback) ->
    db.get design._id, (err, existing) =>
        if existing?.version is design.version
            return callback null
        else
            console.log "REDEFINING DESIGN #{design._id} FROM #{existing}"
            design._rev = existing._rev if existing
            db.put design, callback

PathToBinaryDesignDoc =
    _id: '_design/PathToBinary'
    version: 1
    views:
        'PathToBinary':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'file'
                    emit doc.path + '/' + doc.name, doc.binary?.file?.id


FilesAndFolderDesignDoc =
    _id: '_design/FilesAndFolder'
    version: 1
    views:
        'FilesAndFolder':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() in ['file', 'folder']
                    emit [doc.path, doc.name.toLowerCase()]

LocalPathDesignDoc =
    _id: '_design/LocalPath'
    version: 1
    views:
        'LocalPath':
            map: Object.toString.apply (doc) ->
                emit doc.localPath if doc.localPath

ContactsByLocalIdDesignDoc =
    _id: '_design/ContactsByLocalId'
    version: 1
    views:
        'ContactsByLocalId':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'contact' and doc.localId
                    emit doc.localId, [doc.localVersion, doc._rev]

module.exports = (db, contactsDB, callback) ->

    async.series [
        (cb) -> createOrUpdateDesign db, FilesAndFolderDesignDoc, cb
        (cb) -> createOrUpdateDesign db, LocalPathDesignDoc, cb
        (cb) -> createOrUpdateDesign db, PathToBinaryDesignDoc, cb
        (cb) -> createOrUpdateDesign contactsDB, ContactsByLocalIdDesignDoc, cb
    ], callback