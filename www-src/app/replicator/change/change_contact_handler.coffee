CozyToAndroidContact = require "../transformer/cozy_to_android_contact"
AndroidAccount = require '../fromDevice/android_account'


log = require('../../lib/persistent_log')
    prefix: "ChangeContactHandler"
    date: true

continueOnError = require('../../lib/utils').continueOnError log


module.exports = class ChangeContactHandler

    constructor: ->
        @transformer = new CozyToAndroidContact()

    dispatch: (doc, callback) ->
        @_getFromPhoneByCozyId doc._id, (err, androidContact) =>
            if androidContact?
                if doc._delete
                    @_delete doc, androidContact, continueOnError callback
                else
                    @_update doc, androidContact, continueOnError callback
            else
                # Contact may have already been deleted from device
                # or Contact never been created on device
                unless doc._deleted
                    @_create doc, continueOnError callback

    _create: (doc, callback) ->
        @_update doc, undefined, callback


    _update: (doc, androidContact, callback) ->
        log.info "update"

        try
            toSaveInPhone = @transformer.transform doc
        catch err
            return callback err if err

        if androidContact # Update
            toSaveInPhone.id = androidContact.id
            toSaveInPhone.rawId = androidContact.rawId

        options =
            accountType: AndroidAccount.TYPE
            accountName: AndroidAccount.NAME
            callerIsSyncAdapter: true # apply immediately
            resetFields: true # remove all fields before update

        toSaveInPhone.save ((contact) => callback null, contact), callback
        , options


    _delete: (doc, androidContact, callback) ->
        log.info "delete"
        # Use callerIsSyncAdapter flag to apply immediately in
        # android(no dirty flag cycle)
        androidContact.remove (=> callback()), callback
        , callerIsSyncAdapter: true


    _getFromPhoneByCozyId: (cozyId, cb) ->
        navigator.contacts.find [navigator.contacts.fieldType.sourceId]
        , (contacts) ->
            cb null, contacts[0]
        , cb
        , new ContactFindOptions cozyId, false, [], AndroidAccount.TYPE, \
            AndroidAccount.NAME
