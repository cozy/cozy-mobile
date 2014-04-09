module.exports = ->
    $menu = $('#menu-left-list')
    $menu.append require('../templates/menu')()

    $menu.on 'click', '#refresher', (event) ->
        $('#refresher i').removeClass('ion-loop').addClass('ion-looping')
        event.stopImmediatePropagation()
        app.replicator.sync (err) ->
            alert err if err
            app.router.mainView?.collection?.fetch()
            $('#refresher i').removeClass('ion-looping').addClass('ion-loop')
            menu.toggleLeft()

    doSearch = () ->
        val = $('#search-input').val()
        return true if val.length is 0
        app.router.navigate '#search/' + val, trigger: true
        menu.toggleLeft()

    $menu.on 'click', '#btn-search', doSearch
    $menu.on 'keydown', '#search-input', (event) ->
        doSearch() if event.which is 13

    $menu.on 'click', 'a.item', ->
        menu.toggleLeft()

    content = new ionic.views.SideMenuContent
      el: document.getElementById 'content'

    leftMenu = new ionic.views.SideMenu
      el: $menu[0],
      width: 270

    menu = new ionic.controllers.SideMenuController
      content: content
      left: leftMenu

    menu.reset = ->
        $('#search-input').val('')
        return menu

    return menu