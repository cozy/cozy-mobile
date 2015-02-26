module.exports = class Notifications extends Backbone.View

    # constructor: (options) ->
    #     options = options or {}
    #     @initialize.apply @, arguments

    initialize: ->
        console.log 'in notifications!'
        @listenTo app.replicator, 'change:inSync change:inBackup', @onReplication

        # TODO: ko
        window.plugin.notification.local.onclick = (id, state, json) ->
            console.log id
            console.log json
            alert json

    onReplication: =>
        inSync = app.replicator.get('inSync')
        inBackup = app.replicator.get('inBackup')

        unless inSync or inBackup
            @fetch()

    fetch: =>
        console.log 'in fetch!'
        app.replicator.db.query 'NotificationsForwardMobile', { include_docs: true }, (err, notifications) =>
                notifications.rows.forEach (notification) =>
                    @showNotification notification.doc

    showNotification: (notification) =>
        window.plugin.notification.local.add

            id: notification.publishDate % 100000 # A unique id of the notifiction
        #     #date: new Date()# When popup the notification. (Date)
            message: notification.text # The message that is displayed
            title: "Cozy - #{notification.app}" # The title of the message
        #     #repeat:  # Either 'secondly', 'minutely', 'hourly', 'daily', 'weekly', 'monthly' or 'yearly'
        #     #badge: Number # Displays number badge to notification
        #     #sound: String # A sound to be played
            json: '{"truc":"machine"}' # Data to be passed through the notification
            autoCancel: true # Setting this flag and the notification is automatically canceled when the user clicks it
        #     #ongoing: Boolean # Prevent clearing of notification (Android only)


 # _.extend Notifications.prototype, Events
