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
        oldIcon = if looping then 'ion-loop' else 'ion-looping'
        newIcon = if looping then 'ion-looping' else 'ion-loop'
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


    sync: ->
        return if app.replicator.get 'inSync'
        app.layout.closeMenu()
        app.replicator.sync (err) ->
            alert err if err
            app.layout.currentView?.collection?.fetch()
            app.layout.closeMenu()

    backup: ->
        return if app.replicator.get 'inBackup'
        app.layout.closeMenu()
        app.replicator.backup (err) ->
            alert err if err
            app.layout.currentView?.collection?.fetch()
            app.layout.closeMenu()


    doSearchIfEnter: (event) => @doSearch() if event.which is 13
    doSearch: ->
        val = $('#search-input').val()
        return true if val.length is 0
        app.layout.closeMenu()
        app.router.navigate '#search/' + val, trigger: true

    reset: ->
        @$('#search-input').val('')