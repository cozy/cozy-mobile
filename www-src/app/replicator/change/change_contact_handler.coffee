Contact = require '../../lib/cordova_contact_helper'


log = require('../../lib/persistent_log')
    prefix: "ChangeContactHandler"
    date: true


ACCOUNT_TYPE = 'io.cozy'
ACCOUNT_NAME = 'myCozy'

module.exports = class ChangeContactHandler

    change: (doc) ->
        log.info "change"
        console.log doc
        try
            toSaveInPhone = Contact.cozy2Cordova doc
        catch err
            return @_throwError err

        @_getFromPhoneByCozyId doc._id, (err, phoneContact) =>
            if phoneContact
                toSaveInPhone.id = phoneContact.id
                toSaveInPhone.rawId = phoneContact.rawId

            options =
                accountType: ACCOUNT_TYPE
                accountName: ACCOUNT_NAME
                callerIsSyncAdapter: true # apply immediately
                resetFields: true # remove all fields before update

            toSaveInPhone.save ((contact) => @_done null, contact), @_done, options


    delete: (doc) ->
        log.info "delete"
        console.log doc

        @_getFromPhoneByCozyId doc._id, (err, contact) =>
            return @_throwError err if err
            if contact?
                # Use callerIsSyncAdapter flag to apply immediately in
                # android(no dirty flag cycle)
                contact.remove (=> @_done()), @_done, \
                    callerIsSyncAdapter: true
            # else contact already missing.


    _getFromPhoneByCozyId: (cozyId, cb) ->
        navigator.contacts.find [navigator.contacts.fieldType.sourceId]
        , (contacts) ->
            cb null, contacts[0]
        , cb
        , new ContactFindOptions cozyId, false, [], ACCOUNT_TYPE, \
            ACCOUNT_NAME

    _done: (err, result) ->
        return log.error err if err
        log.debug result

    _throwError: (err) ->
        log.error err
