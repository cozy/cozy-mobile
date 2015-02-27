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
                if doc.name?
                    if doc.docType?.toLowerCase() is 'file'
                        emit [doc.path, '2_' + doc.name.toLowerCase()]
                    if doc.docType?.toLowerCase() is 'folder'
                        emit [doc.path, '1_' + doc.name.toLowerCase()]

PicturesDesignDoc =
    _id: '_design/Pictures'
    version: 1
    views:
        'Pictures':
            map: Object.toString.apply (doc) ->
                if doc.lastModification?
                    if doc.docType?.toLowerCase() is 'file'
                        emit [doc.path, doc.lastModification]

NotificationsForwardMobileDesignDoc =
    _id: '_design/NotificationsForwardMobile'
    version: 1
    views:
        'NotificationsForwardMobile':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'notification' #and doc.forward_mobile is true
                    emit doc._id

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

PhotosByLocalIdDesignDoc =
    _id: '_design/PhotosByLocalId'
    version: 1
    views:
        'PhotosByLocalId':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'photo'
                    emit doc.localId

DevicesByLocalIdDesignDoc =
    _id: '_design/DevicesByLocalId'
    version: 2
    views:
        'DevicesByLocalId':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'device'
                    emit doc.localId, doc

module.exports = (db, contactsDB, photosDB, callback) ->

    async.series [
        (cb) -> createOrUpdateDesign db, NotificationsForwardMobileDesignDoc, cb
        (cb) -> createOrUpdateDesign db, FilesAndFolderDesignDoc, cb
        (cb) -> createOrUpdateDesign db, PicturesDesignDoc, cb
        (cb) -> createOrUpdateDesign db, LocalPathDesignDoc, cb
        (cb) -> createOrUpdateDesign db, PathToBinaryDesignDoc, cb
        (cb) -> createOrUpdateDesign contactsDB, ContactsByLocalIdDesignDoc, cb
        (cb) -> createOrUpdateDesign photosDB, PhotosByLocalIdDesignDoc, cb
        (cb) -> createOrUpdateDesign photosDB, DevicesByLocalIdDesignDoc, cb
    ], callback
