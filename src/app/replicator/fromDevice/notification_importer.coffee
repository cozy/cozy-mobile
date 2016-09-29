NotificationHandler = require '../../lib/notification_handler'

log = require('../../lib/persistent_log')
    prefix: "NotificationImporter"
    date: true


module.exports = class NotificationImporter


    constructor: ->
        @notificationHandler = new NotificationHandler()


    synchronize: (callback) ->
        @notificationHandler.deletesIfIsNotPresent callback
