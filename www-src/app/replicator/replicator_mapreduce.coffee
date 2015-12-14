log = require('../lib/persistent_log')
    prefix: "replicator mapreduce"
    date: true

createOrUpdateDesign = (db, design, callback) ->
    db.get design._id, (err, existing) =>
        if existing?.version is design.version
            return callback null
        else
            log.info "REDEFINING DESIGN #{design._id} FROM #{existing}"
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

ByBinaryIdDesignDoc =
    _id: '_design/ByBinaryId'
    version: 1
    views:
        'ByBinaryId':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'file'
                    emit doc.binary?.file?.id

PicturesDesignDoc =
    _id: '_design/Pictures'
    version: 1
    views:
        'Pictures':
            map: Object.toString.apply (doc) ->
                if doc.lastModification?
                    if doc.docType?.toLowerCase() is 'file'
                        emit [doc.path, doc.lastModification]

NotificationsTemporaryDesignDoc =
    _id: '_design/NotificationsTemporary'
    version: 1
    views:
        'NotificationsTemporary':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'notification' and doc.type is 'temporary'
                    emit doc._id

LocalPathDesignDoc =
    _id: '_design/LocalPath'
    version: 1
    views:
        'LocalPath':
            map: Object.toString.apply (doc) ->
                emit doc.localPath if doc.localPath

ContactsDesignDoc =
    _id: '_design/Contacts'
    version: 1
    views:
        'Contacts':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'contact'
                    emit doc._id


CalendarsDesignDoc =
    _id: '_design/Calendars'
    version: 2
    views:
        'Calendars':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'event'
                    emit doc.tags?[0]



PhotosByLocalIdDesignDoc =
    _id: '_design/PhotosByLocalId'
    version: 1
    views:
        'PhotosByLocalId':
            map: Object.toString.apply (doc) ->
                if doc.docType?.toLowerCase() is 'photo'
                    emit doc.localId


module.exports = (db, photosDB, callback) ->

    async.series [
        (cb) -> createOrUpdateDesign db, NotificationsTemporaryDesignDoc, cb
        (cb) -> createOrUpdateDesign db, FilesAndFolderDesignDoc, cb
        (cb) -> createOrUpdateDesign db, ByBinaryIdDesignDoc, cb
        (cb) -> createOrUpdateDesign db, PicturesDesignDoc, cb
        (cb) -> createOrUpdateDesign db, LocalPathDesignDoc, cb
        (cb) -> createOrUpdateDesign db, PathToBinaryDesignDoc, cb
        (cb) -> createOrUpdateDesign db, ContactsDesignDoc, cb
        (cb) -> createOrUpdateDesign db, CalendarsDesignDoc, cb
        (cb) -> createOrUpdateDesign photosDB, PhotosByLocalIdDesignDoc, cb
    ], callback
