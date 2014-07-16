BaseView = require '../lib/base_view'

module.exports = class Menu extends BaseView

    id: 'menu'
    className: 'menu menu-left'
    template: require '../templates/menu'
    events:
        'click #refresher': 'refresh'
        'click #refreshContacts': 'refreshContacts'
        'click #btn-search': 'doSearch'
        'click a.item': 'closeMenu'
        'keydown #search-input': 'doSearchIfEnter'

    refresh: ->
        @$('#refresher i').removeClass('ion-loop').addClass('ion-looping')
        event.stopImmediatePropagation()
        app.replicator.sync (err) ->
            alert err if err
            app.layout.currentView?.collection?.fetch()
            @$('#refresher i').removeClass('ion-looping').addClass('ion-loop')
            app.layout.closeMenu()

    refreshContacts: ->
        app.replicator.syncContacts (err) ->
            console.log "SYNC DONE"
            return alert err if err
            app.replicator.replicateContacts (err) ->
                alert err if err
                console.log "REPLICATION DONE"

    doSearchIfEnter: (event) => @doSearch() if event.which is 13
    doSearch: ->
        val = $('#search-input').val()
        return true if val.length is 0
        app.layout.closeMenu()
        app.router.navigate '#search/' + val, trigger: true

    reset: ->
        @$('#search-input').val('')