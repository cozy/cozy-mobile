async = require 'async'
AndroidAccount = require './android_account'
CozyToAndroidContact = require "../transformer/cozy_to_android_contact"

log = require('../../lib/persistent_log')
    prefix: "ContactImporter"
    date: true

continueOnError = require('../../lib/utils').continueOnError log

###*
 * Import changes (dirty rows) from android contact database to PouchDB
 *
###
module.exports = class ContactImporter

    constructor: (@db) ->
        @db ?= app.replicator.config.db
        @transformer = new CozyToAndroidContact()

    # Sync dirty (modified) phone contact to app's pouchDB.
    synchronize: ->
        log.info "synchronize"

        # Go through modified contacts (dirtys)
        # delete, update or create....
        navigator.contacts.find [navigator.contacts.fieldType.dirty]
        , (contacts) =>
            processed = 0
            log.info "syncPhone2Pouch #{contacts.length} contacts."
            # contact to update number. contacts.length
            async.eachSeries contacts, (contact, cb) =>
                setImmediate => # helps refresh UI
                    if contact.deleted
                        @_delete contact, continueOnError cb
                    else if contact.sourceId
                        @_update contact, continueOnError cb
                    else
                        @_create contact, continueOnError cb
            , callback

        , callback
        , new ContactFindOptions "1", true, []
        , AndroidAccount.TYPE, AndroidAccount.NAME


    # Update contact in pouchDB with specified contact from phone.
    # @param phoneContact cordova contact format.
    _update: (phoneContact, callback) ->
        async.parallel
            fromPouch: (cb) =>
                @db.get phoneContact.sourceId,  attachments: true, cb

            fromPhone: (cb) ->
                @transformer.reverseTransform phoneContact, cb
        , (err, res) =>
            return callback err if err

            # _.extend : Keeps not android compliant data of the 'cozy'-contact
            contact = _.extend res.fromPouch, res.fromPhone

            if contact._attachments?.picture?
                picture = contact._attachments.picture

                if res.fromPouch._attachments?.picture?
                    oldPicture = res.fromPouch._attachments?.picture?
                    if oldPicture.data is picture.data
                        picture.revpos = oldPicture.revpos
                    else
                        picture.revpos = 1 + \
                            parseInt contact._rev.split('-')[0]

            @db.put contact, contact._id, contact._rev, (err, idNrev) =>
                return callback err if err
                @_undirty phoneContact, idNrev, callback


    # Create a new contact in app's pouchDB from newly created phone contact.
    # @param phoneContact cordova contact format.
    # @param retry retry lighter update after a failed one.
    _create: (phoneContact, callback) ->
        @transformer.reverseTransform phoneContact, (err, fromPhone) =>
            contact = _.extend
                docType: 'contact'
                tags: []
            , fromPhone

            if contact._attachments?.picture?
                contact._attachments.picture.revpos = 1

            @db.post contact, (err, idNrev) =>
                return callback err if err
                @_undirty phoneContact, idNrev, callback



    # Delete the specified contact in app's pouchdb.
    # @param phoneContact cordova contact format.
    _delete: (phoneContact, callback) ->
        toDelete =
            docType: 'contact'
            _id: phoneContact.sourceId
            _rev: phoneContact.sync2
            _deleted: true

        @db.put toDelete, toDelete._id, toDelete._rev, (err, res) ->
            return callback err if err
            phoneContact.remove (-> callback()), callback, \
                    callerIsSyncAdapter: true



    # Notify to Android that the contact have been synchronized with the server.
    # @param dirtyContact cordova contact format.
    # @param idNrew object with id and rev of pouchDB contact.
    _undirty: (dirtyContact, idNrev, callback) ->
        # undirty and set id and rev on phone contact.
        dirtyContact.dirty = false
        dirtyContact.sourceId = idNrev.id
        dirtyContact.sync2 = idNrev.rev

        dirtyContact.save () ->
            callback null
        , callback
        ,
            accountType: AndroidAccount.TYPE
            accountName: AndroidAccount.NAME
            callerIsSyncAdapter: true
































        @calendarSync.dirtyEvents AndroidCalendarHandler.ACCOUNT, \
                (err, androidEvents) =>
            return log.error err if err

            async.eachSeries androidEvents, (androidEvent, cb) =>
                @change androidEvent, cb

    change: (androidEvent, callback) ->
        log.info "change"

        if androidEvent.deleted
            @delete androidEvent, continueOnError callback
        else
            @androidCalendarHandler.getById androidEvent.calendar_id, \
                (err, androidCalendar) =>
                    return log.error err if err

                    if androidEvent._sync_id
                        @update androidEvent, androidCalendar, continueOnError \
                                callback
                    else
                        @create androidEvent, androidCalendar, continueOnError \
                                callback

    # Create a new contact in app's pouchDB from newly created phone contact.
    # @param phoneContact cordova contact format.
    # @param retry retry lighter update after a failed one.
    create: (androidEvent, androidCalendar, callback) ->
        log.info "create"

        cozyEvent = @cozyToAndroidEvent.reverseTransform androidEvent, \
                androidCalendar

        @db.post cozyEvent, (err, response) =>
            return callback err if err

            androidEvent._sync_id = response.id
            androidEvent.sync_data2 = response.rev

            @calendarSync.undirtyEvent androidEvent, \
                    AndroidCalendarHandler.ACCOUNT, callback

    # Update event in pouchDB with specified event from phone.
    # @param androidEvent
    # @param retry retry lighter update after a failed one.
    update: (androidEvent, androidCalendar, callback) ->
        log.info "update"

        @db.get androidEvent._sync_id, (err, cozyEvent) =>
            return callback err if err

            cozyEvent = @cozyToAndroidEvent.reverseTransform androidEvent, \
                    androidCalendar, cozyEvent

            @db.put cozyEvent, cozyEvent._id, cozyEvent._rev, (err, response) =>
                return callback err if err

                androidEvent.sync_data2 = response.rev
                androidEvent.sync_data5 = cozyEvent.lastModified

                @calendarSync.undirtyEvent androidEvent, \
                        AndroidCalendarHandler.ACCOUNT, callback


    # Delete the specified contact in app's pouchdb.
    # @param phoneContact cordova contact format.
    delete: (androidEvent, callback) ->
        log.info "delete"

        toDelete =
            docType: 'event'
            _id: androidEvent._sync_id
            _rev: androidEvent.sync_data2
            _deleted: true

        @db.put toDelete, toDelete._id, toDelete._rev, (err, res) =>
            return callback err if err

            @calendarSync.deleteEvent androidEvent, \
                    AndroidCalendarHandler.ACCOUNT, callback
