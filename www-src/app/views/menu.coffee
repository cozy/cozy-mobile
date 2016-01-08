BaseView = require '../lib/base_view'

log = require('../lib/persistent_log')
    prefix: "Menu"
    date: true

module.exports = class Menu extends BaseView

    id: 'menu'
    className: 'menu menu-left'
    template: require '../templates/menu'
    events:
        'click #close-menu': 'closeMenu'
        # 'click #syncButton': 'test'
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
        app.replicator.sync {}, (err) ->
            if err
                log.error err
                alert t if err.message? then err.message else "no connection"
            app.layout.currentView?.collection?.fetch()


    backup: ->
        app.layout.closeMenu()

        if app.replicator.get 'inBackup'
            @sync()
        else
            app.replicator.backup { force: false }, (err) =>
                if err
                    log.error err
                    alert t err.message
                    return

                app.layout.currentView?.collection?.fetch()
                @sync()

    doSearchIfEnter: (event) => @doSearch() if event.which is 13
    doSearch: ->
        val = $('#search-input').val().toLowerCase()
        return true if val.length is 0
        app.layout.closeMenu()
        app.router.navigate '#search/' + val, trigger: true

    reset: ->
        @$('#search-input').blur().val('')
