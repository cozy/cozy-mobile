CozyToAndroidContact = require "../transformer/cozy_to_android_contact"
AndroidAccount = require '../fromDevice/android_account'
Permission = require '../../lib/permission'

log = require('../../lib/persistent_log')
    prefix: "ChangeContactHandler"
    date: true

continueOnError = require('../../lib/utils').continueOnError log


module.exports = class ChangeContactHandler

    constructor: ->
        @cozyToAndroidContact = new CozyToAndroidContact()
        @permission = new Permission()


    dispatch: (doc, callback) ->

        @_getFromPhoneByCozyId doc._id, (err, androidContact) =>
            if androidContact?
                if doc._deleted
                    @_delete doc, androidContact, continueOnError callback
                else
                    @_update doc, androidContact, continueOnError callback
            else
                # Contact may have already been deleted from device
                # or Contact never been created on device
                if doc._deleted
                    callback()
                else
                    @_create doc, continueOnError callback


    _create: (doc, callback) ->
        log.info "create"

        @_update doc, undefined, callback


    _update: (doc, androidContact, callback) ->
        log.info "update" if androidContact

        @_setPictureBase64data doc, (doc) =>
            try
                toSaveInPhone = @cozyToAndroidContact.transform doc
                toSaveInPhone = navigator.contacts.create toSaveInPhone
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

            toSaveInPhone.save ((contact) -> callback null, contact), callback
            , options


    _delete: (doc, androidContact, callback) ->
        log.info "delete"

        # Use callerIsSyncAdapter flag to apply immediately in
        # android(no dirty flag cycle)
        androidContact.remove (-> callback()), callback
        , callerIsSyncAdapter: true


    _getFromPhoneByCozyId: (cozyId, callback) ->

        success = =>
            navigator.contacts.find [navigator.contacts.fieldType.sourceId]
            , (contacts) ->
                callback null, contacts[0]
            , callback
            , new ContactFindOptions cozyId, false, [], AndroidAccount.TYPE, \
                AndroidAccount.NAME

        @permission.checkPermission 'contacts', success, callback


    _setPictureBase64data: (doc, callback) ->

        if doc._attachments is undefined or 'picture' not of doc._attachments
            return callback doc
        return callback doc if typeof doc._attachments.picture.data is 'string'

        reader = new FileReader()
        reader.onload = ->
            data = reader.result
            prefix = 'data:application/octet-stream;base64,'
            if data and data.startsWith prefix
                data = data.substr prefix.length
            doc._attachments.picture.data = data
            callback doc
        reader.onerror = ->
            callback doc
        reader.readAsDataURL doc._attachments.picture.data
