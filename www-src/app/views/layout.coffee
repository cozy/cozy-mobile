# This view is responsible to handle ionic complexities :
# - scrolling
# - sliding transitions

BaseView = require '../lib/base_view'
FolderView = require './folder'
Menu = require './menu'
BreadcrumbsView = require './breadcrumbs'

module.exports = class Layout extends BaseView

    template: require '../templates/layout'

    events: ->
        'tap #btn-back': 'onBackButtonClicked'
        'tap #btn-menu': 'onMenuButtonClicked'

    initialize: ->
        document.addEventListener "menubutton", @onMenuButtonClicked, false
        document.addEventListener "searchbutton", @onSearchButtonClicked, false
        document.addEventListener "backbutton", @onBackButtonClicked, false

        @listenTo app.replicator, 'change:inSync change:inBackup', =>

            inSync = app.replicator.get('inSync')
            inBackup = app.replicator.get('inBackup')
            @spinner.toggle inSync or inBackup

        OpEvents = 'change:inBackup change:backup_step change:backup_step_done'
        @listenTo app.replicator, OpEvents, _.debounce =>
            step = app.replicator.get 'backup_step'
            if step and step not in ['pictures_scan']
                text = t step
                if app.replicator.get 'backup_step_done'
                    text += ": #{app.replicator.get 'backup_step_done'}"
                    text += "/#{app.replicator.get 'backup_step_total'}"
                @backupIndicator.text(text).parent().slideDown()
                @viewsPlaceholder.addClass 'has-subheader'
            else
                @backupIndicator.parent().slideUp()
                @viewsPlaceholder.removeClass 'has-subheader'

        , 100

    afterRender: ->
        @menu = new Menu()
        @menu.render()
        @$el.append @menu.$el

        @container = @$('#container')
        @viewsPlaceholder = @$('#viewsPlaceholder')
        @viewsBlock = @viewsPlaceholder.find('.scroll')

        @backButton = @container.find '#btn-back'
        @menuButton = @container.find '#btn-menu'
        @iconLogo = @container.find '#icon-logo'
        @spinner = @container.find '#headerSpinner'
        @spinner.hide()
        @title = @container.find '#title'
        @backupIndicator = @container.find '#backupIndicator'
        @backupIndicator.parent().hide()

        @ionicContainer = new ionic.views.SideMenuContent
            el: @container[0]

        @ionicMenu = new ionic.views.SideMenu
            el: @menu.$el[0]
            width: 270

        @controller = new ionic.controllers.SideMenuController
            content: @ionicContainer
            left: @ionicMenu

        @ionicScroll = new ionic.views.Scroll
            el: @viewsPlaceholder[0]
            bouncing: false

        # Force scroll to display tree
        @ionicScroll.scrollTo 1, 0, true, null
        @ionicScroll.scrollTo 0, 0, true, null

    isMenuOpen: =>
        return @controller.isOpenLeft()

    closeMenu: =>
        @controller.toggleLeft false

    quitSplashScreen: ->
        $('body').empty().append @render().$el
        $('body').css 'background-color', 'white'

    setBackButton: (href, icon) =>
        @backButton.attr 'href', href
        @backButton.removeClass 'ion-home ion-ios7-arrow-back'
        @backButton.addClass 'ion-' + icon

    setTitle: (text) =>
        @$('#breadcrumbs').remove()
        @title.text text
        @title.show()

    setBreadcrumbs: (path) ->
        @$('#breadcrumbs').remove()
        @title.hide()
        @iconLogo.hide()
        breadcrumbsView = new BreadcrumbsView path: path
        @title.after breadcrumbsView.render().$el
        # breadcrumbsView.scrollLeft()

    transitionTo: (view) ->
        @closeMenu()
        $next = view.render().$el

        # prevent menu on login
        menuEnabled = view.menuEnabled? and view.menuEnabled
        @ionicMenu.setIsEnabled menuEnabled

        if @currentView instanceof FolderView and view instanceof FolderView
            type = if @currentView.isParentOf(view) then 'left' else 'right'
        else
            type = 'none'

        if type is 'none' # no animation
            @currentView?.remove()
            @viewsBlock.append $next
            @ionicScroll.hintResize()
            @currentView = view
            @ionicScroll.scrollTo 0, 0, false, null

        else

            nextClass =
                if type is 'left' then 'sliding-next' else 'sliding-prev'
            currClass =
                if type is 'left' then 'sliding-prev' else 'sliding-next'

            $next.addClass nextClass
            @viewsBlock.append $next
            $next.width() # force reflow

            @currentView.$el.addClass currClass
            $next.removeClass nextClass

            transitionend = 'webkitTransitionEnd otransitionend ' +
                'oTransitionEnd msTransitionEnd transitionend'
            # double one & once because there is multiple events type
            $next.one transitionend, _.once =>
                @currentView.remove()
                @currentView = view
                @ionicScroll.scrollTo 0, 0, false, null


    onMenuButtonClicked: =>
        @menu.reset()
        @controller.toggleLeft()

    onSearchButtonClicked: =>
        @onMenuButtonClicked()
        @$('#search-input').focus()

    onBackButtonClicked: (event) =>
        # close menu first
        if @isMenuOpen()
            @closeMenu()

        # @TODO: we could go further in history, but history.back() has
        # strange behaviour near first screen
        else if location.href.indexOf('#folder/') is (location.href.length - 8)
            if window.confirm t "confirm exit message"
                navigator.app.exitApp()

        else
            # navigator.app.backHistory()
            window.history.back()
