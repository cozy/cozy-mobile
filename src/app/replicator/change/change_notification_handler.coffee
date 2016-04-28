NotificationHandler = require '../../lib/notification_handler'

log = require('../../lib/persistent_log')
    prefix: "ChangeNotificationHandler"
    date: true


###*
 * ChangeNotificationHandler Can create, update or delete a notification on
 * your device
 *
 * @class ChangeNotificationHandler
###
module.exports = class ChangeNotificationHandler


    constructor: (@notifHandler) ->
        @notifHandler ?= new NotificationHandler()


    dispatch: (cozyNotification, callback) ->
        log.debug "dispatch"

        if cozyNotification._deleted
            @notifHandler.removeCordovaNotification cozyNotification, callback
        else
            @notifHandler.displayCordovaNotification cozyNotification, callback
