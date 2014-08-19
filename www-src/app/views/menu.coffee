BaseView = require '../lib/base_view'

module.exports = class Menu extends BaseView

    id: 'menu'
    className: 'menu menu-left'
    template: require '../templates/menu'
    events:
        'click #syncButton': 'sync'
        'click #backupButton': 'backup'
        'click #btn-search': 'doSearch'
        'click a.item': 'closeMenu'
        'keydown #search-input': 'doSearchIfEnter'

    setLooping = (btn, looping) ->
        oldIcon = if looping then 'ion-ios7-cloud-upload-outline' else 'ion-looping'
        newIcon = if looping then 'ion-looping' else 'ion-ios7-cloud-upload-outline'
        btn.find('i').removeClass(oldIcon).addClass(newIcon)

    afterRender: ->
        @syncButton = @$ '#syncButton'
        @backupButton = @$ '#backupButton'

        @listenTo app.replicator, 'change:inSync', =>
            setLooping @syncButton, app.replicator.get 'inSync'

        @listenTo app.replicator, 'change:inBackup', =>
            setLooping @backupButton, app.replicator.get 'inBackup'

        setLooping @syncButton, app.replicator.get 'inSync'
        setLooping @backupButton, app.replicator.get 'inBackup'

    closeMenu: -> app.layout.closeMenu()

    sync: ->
        return if app.replicator.get 'inSync'
        app.layout.closeMenu()
        app.replicator.sync (err) ->
            console.log err, err.stack if err
            alert err if err
            app.layout.currentView?.collection?.fetch()

    backup: ->
        return if app.replicator.get 'inBackup'
        app.layout.closeMenu()
        app.replicator.backup (err) ->
            console.log err, err.stack if err
            alert err if err
            app.layout.currentView?.collection?.fetch()


    doSearchIfEnter: (event) => @doSearch() if event.which is 13
    doSearch: ->
        val = $('#search-input').val()
        return true if val.length is 0
        app.layout.closeMenu()
        app.router.navigate '#search/' + val, trigger: true

    reset: ->
        @$('#search-input').blur().val('')