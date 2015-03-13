module.exports = class Notifications
    _.extend Notifications.prototype, Backbone.Events

    constructor: (options) ->
        options = options or {}
        @initialize.apply @, arguments

    initialize: ->
        @listenTo app.replicator, 'change:inSync', @onSync

    onSync: =>
        inSync = app.replicator.get 'inSync'

        # Filter sync finished
        unless inSync
            @fetch()

    fetch: =>
        app.replicator.db.query 'NotificationsTemporary', { include_docs: true }, (err, notifications) =>
                notifications.rows.forEach (notification) =>
                    @showNotification notification.doc

    # Delete doc in (locale) db.
    #
    # @TODO: may generate conflict between pouchDB and cozy's couchDB, with
    # persistant notifcations (ie updated in couchDB). But currently only
    # 'temporary' notifications are showed.
    markAsShown: (notification) =>
        app.replicator.db.remove notification, (err) ->
            if err
                console.log "Error while removing notification."
                console.log err

            return console.log err.message if err

    showNotification: (notification) =>
        # generate id : android require an 'int' id, we generate it from the
        # too long couchDB _id.
        id = parseInt notification._id.slice(-7), 16
        if isNaN id # if id wasn't an hexa chain, fallback on timestamp.
            id = notification.publishDate % 10000000

        window.plugin.notification.local.add
            id: id
            message: notification.text # The message that is displayed
            title: "Cozy - #{notification.app or 'Notification' }" # The title of the message
            #badge: Number # Displays number badge to notification
            #sound: String # A sound to be played
            #json: # Data to be passed through the notification
            autoCancel: true # Setting this flag and the notification is automatically canceled when the user clicks it

        # @TODO : notification should be marked as shown on dismiss/click,
        # instead of as popup.
        @markAsShown notification
