async = require 'async'
log = require('../lib/persistent_log')
    prefix: "Design Documents"
    date: true

module.exports = class DesignDocuments

    # Design names
    @PATH_TO_BINARY: 'PathToBinary'
    @FILES_AND_FOLDER: 'FilesAndFolder'
    @PICTURES: 'Pictures'
    @PHOTOS_BY_LOCAL_ID: 'PhotosByLocalId'
    @BY_BINARY_ID: 'ByBinaryId'
    @NOTIFICATIONS_TEMPORARY: 'NotificationsTemporary'
    @LOCAL_PATH: 'LocalPath'
    @CONTACTS: 'Contacts'
    @CALENDARS: 'Calendars'

    # Databases
    cozyDB: null
    internalDB: null

    constructor: (@cozyDB, @internalDB) ->

    createOrUpdateAllDesign: (callback) ->
        log.info 'createOrUpdateAllDesign'
        async.series [
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.NotificationsTemporaryDesignDoc, next
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.FilesAndFolderDesignDoc, next
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.ByBinaryIdDesignDoc, next
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.PicturesDesignDoc, next
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.LocalPathDesignDoc, next
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.PathToBinaryDesignDoc, next
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.ContactsDesignDoc, next
            (next) => @_createOrUpdate @cozyDB, \
                DesignDocuments.CalendarsDesignDoc, next
            (next) => @_createOrUpdate @internalDB, \
                DesignDocuments.PhotosByLocalIdDesignDoc, next
        ], callback

    _createOrUpdate: (db, design, callback) ->
        db.get design._id, (err, existing) ->
            if existing?.version is design.version
                callback null, {}
            else
                if existing
                    log.info "Update: #{design._id} FROM #{existing.version}" \
                            + "TO #{design.version}"
                    design._rev = existing._rev
                else
                    log.info "Create: #{design._id}"
                db.put design, callback


    # Design Documents

    @PathToBinaryDesignDoc:
        _id: "_design/#{@PATH_TO_BINARY}"
        version: 1
        views:
            "#{@PATH_TO_BINARY}":
                map: Object.toString.apply (doc) ->
                    if doc.docType?.toLowerCase() is 'file'
                        emit doc.path + '/' + doc.name, doc.binary?.file?.id


    @FilesAndFolderDesignDoc:
        _id: "_design/#{@FILES_AND_FOLDER}"
        version: 1
        views:
            "#{@FILES_AND_FOLDER}":
                map: Object.toString.apply (doc) ->
                    if doc.name?
                        if doc.docType?.toLowerCase() is 'file'
                            emit [doc.path, '2_' + doc.name.toLowerCase()]
                        if doc.docType?.toLowerCase() is 'folder'
                            emit [doc.path, '1_' + doc.name.toLowerCase()]


    @ByBinaryIdDesignDoc:
        _id: "_design/#{@BY_BINARY_ID}"
        version: 1
        views:
            "#{@BY_BINARY_ID}":
                map: Object.toString.apply (doc) ->
                    if doc.docType?.toLowerCase() is 'file'
                        emit doc.binary?.file?.id


    @PicturesDesignDoc:
        _id: "_design/#{@PICTURES}"
        version: 1
        views:
            "#{@PICTURES}":
                map: Object.toString.apply (doc) ->
                    if doc.lastModification?
                        if doc.docType?.toLowerCase() is 'file'
                            emit [doc.path, doc.lastModification]


    @NotificationsTemporaryDesignDoc:
        _id: "_design/#{@NOTIFICATIONS_TEMPORARY}"
        version: 1
        views:
            "#{@NOTIFICATIONS_TEMPORARY}":
                map: Object.toString.apply (doc) ->
                    if doc.docType?.toLowerCase() is 'notification' and \
                            doc.type is 'temporary'
                        emit doc._id


    @LocalPathDesignDoc:
        _id: "_design/#{@LOCAL_PATH}"
        version: 1
        views:
            "#{@LOCAL_PATH}":
                map: Object.toString.apply (doc) ->
                    emit doc.localPath if doc.localPath


    @ContactsDesignDoc:
        _id: "_design/#{@CONTACTS}"
        version: 1
        views:
            "#{@CONTACTS}":
                map: Object.toString.apply (doc) ->
                    if doc.docType?.toLowerCase() is 'contact'
                        emit doc._id


    @CalendarsDesignDoc:
        _id: "_design/#{@CALENDARS}"
        version: 2
        views:
            "#{@CALENDARS}":
                map: Object.toString.apply (doc) ->
                    if doc.docType?.toLowerCase() is 'event'
                        emit doc.tags?[0]


    @PhotosByLocalIdDesignDoc:
        _id: "_design/#{@PHOTOS_BY_LOCAL_ID}"
        version: 1
        views:
            "#{@PHOTOS_BY_LOCAL_ID}":
                map: Object.toString.apply (doc) ->
                    if doc.docType?.toLowerCase() is 'photo'
                        emit doc.localId
