async = require 'async'
AndroidAccount = require './android_account'
CozyToAndroidContact = require "../transformer/cozy_to_android_contact"
Permission = require '../../lib/permission'

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
        @db ?= app.init.database.replicateDb
        @transformer = new CozyToAndroidContact()
        @permission = new Permission()


    synchronize: (callback) ->
        success = =>
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

        @permission 'contacts', success, callback


    # Update contact in pouchDB with specified contact from phone.
    # @param phoneContact cordova contact format.
    _update: (phoneContact, callback) ->
        async.parallel
            fromPouch: (cb) =>
                @db.get phoneContact.sourceId,  attachments: true, cb

            fromPhone: (cb) =>
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

            @db.put contact, (err, idNrev) =>
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

        @db.put toDelete, (err, res) ->
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
