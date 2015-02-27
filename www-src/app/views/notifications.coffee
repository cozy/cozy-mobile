module.exports = class Notifications
    _.extend Notifications.prototype, Backbone.Events

    constructor: (options) ->
        options = options or {}
        @initialize.apply @, arguments

    initialize: ->
        @listenTo app.replicator, 'change:inSync change:inBackup', @onReplication

    onReplication: =>
        inSync = app.replicator.get('inSync')
        inBackup = app.replicator.get('inBackup')

        unless inSync or inBackup
            @fetch()

    fetch: =>
        app.replicator.db.query 'NotificationsForwardMobile', { include_docs: true }, (err, notifications) =>
                notifications.rows.forEach (notification) =>
                    @showNotification notification.doc

    markAsShown: (notification) =>
        # Actualy delete doc in (locale) db.
        app.replicator.db.remove notification, (err) ->
            if err
                console.log "Error while removing notification."
                console.log err

            return console.log err.message if err

    showNotification: (notification) =>
        window.plugin.notification.local.add
            id: notification.publishDate % 100000 # A unique id of the notifiction
            message: notification.text # The message that is displayed
            title: "Cozy - #{notification.app or 'Notification' }" # The title of the message
            #badge: Number # Displays number badge to notification
            #sound: String # A sound to be played
            #json: # Data to be passed through the notification
            autoCancel: true # Setting this flag and the notification is automatically canceled when the user clicks it

        # @TODO : notification should be marked as shown on dismiss/click,
        # instead of as popup.
        @markAsShown notification
