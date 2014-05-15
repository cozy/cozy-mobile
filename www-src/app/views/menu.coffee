BaseView = require '../lib/base_view'

module.exports = class Menu extends BaseView

    id: 'menu'
    className: 'menu menu-left'
    template: require '../templates/menu'
    events:
        'click #refresher': 'refresh'
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

    doSearchIfEnter: (event) => @doSearch() if event.which is 13
    doSearch: ->
        val = $('#search-input').val()
        return true if val.length is 0
        app.layout.closeMenu()
        app.router.navigate '#search/' + val, trigger: true

    reset: ->
        @$('#search-input').val('')