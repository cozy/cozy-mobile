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

    backup: ->
        app.layout.closeMenu()
        app.init.launchBackup()

    doSearchIfEnter: (event) => @doSearch() if event.which is 13
    doSearch: ->
        val = $('#search-input').val().toLowerCase()
        return true if val.length is 0
        app.layout.closeMenu()
        app.router.navigate '#search/' + val, trigger: true

    reset: ->
        @$('#search-input').blur().val('')
