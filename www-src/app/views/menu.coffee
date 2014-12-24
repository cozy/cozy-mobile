BaseView = require '../lib/base_view'

module.exports = class Menu extends BaseView

    id: 'menu'
    className: 'menu menu-left'
    template: require '../templates/menu'
    events:
        'click #syncButton': 'backup'
        'click #btn-search': 'doSearch'
        'click a.item': 'closeMenu'
        'keydown #search-input': 'doSearchIfEnter'


    afterRender: ->
        @syncButton = @$ '#syncButton'
        @backupButton = @$ '#backupButton'

    closeMenu: -> app.layout.closeMenu()

    sync: ->
        return if app.replicator.get 'inSync'
        app.replicator.sync (err) ->
            console.log err, err.stack if err
            alert err if err
            app.layout.currentView?.collection?.fetch()

    backup: ->
        app.layout.closeMenu()
        if app.replicator.get 'inBackup'
            @sync()
        else
            app.replicator.backup (err) =>
                console.log err, err.stack if err
                alert err if err
                app.layout.currentView?.collection?.fetch()
                @sync()


    doSearchIfEnter: (event) => @doSearch() if event.which is 13
    doSearch: ->
        val = $('#search-input').val()
        return true if val.length is 0
        app.layout.closeMenu()
        app.router.navigate '#search/' + val, trigger: true

    reset: ->
        @$('#search-input').blur().val('')