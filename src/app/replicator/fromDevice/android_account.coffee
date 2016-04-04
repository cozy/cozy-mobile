log = require('../../lib/persistent_log')
    prefix: "AndroidAccount"
    date: true

module.exports = class AndroidAccount

    @NAME: 'myCozy'
    @TYPE: 'io.cozy'
    @ACCOUNT:
        accountName: AndroidAccount.NAME
        accountType: AndroidAccount.TYPE

    create: (callback) ->
        log.debug "create"

        navigator.contacts.createAccount AndroidAccount.TYPE
        , AndroidAccount.NAME, ->
            callback null
        , callback
