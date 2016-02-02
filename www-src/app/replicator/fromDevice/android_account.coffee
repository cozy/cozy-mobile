log = require('../../lib/persistent_log')
    prefix: "AndroidAccount"
    date: true

module.exports = class AndroidAccount

    @NAME: 'myCozy'
    @TYPE: 'io.cozy'
    @ACCOUNT:
        name: AndroidAccount.NAME
        type: AndroidAccount.TYPE

    create: (callback) ->
        navigator.contacts.createAccount AndroidAccount.TYPE
        , AndroidAccount.NAME, ->
            callback null
        , callback
