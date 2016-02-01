log = require('../../lib/persistent_log')
    prefix: "AndroidAccount"
    date: true

module.exports = class AndroidAccount

    @account:
        name: 'myCozy'
        type: 'io.cozy'

    upsert: (callback) ->
        navigator.contacts.createAccount @account.type, @account.name
        , ->
            callback null
        , callback
