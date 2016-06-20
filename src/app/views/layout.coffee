# This view is responsible to handle ionic complexities :
# - scrolling
# - sliding transitions

BaseView = require '../lib/base_view'
FolderView = require './folder'
Menu = require './menu'
BreadcrumbsView = require './breadcrumbs'

log = require('../lib/persistent_log')
    prefix: "LayoutView"
    date: true

module.exports = class Layout extends BaseView

    template: require '../templates/layout'


    events: ->
        'tap #btn-back': 'onBackButtonClicked'
        'tap #btn-menu': 'onMenuButtonClicked'
        'tap #closeerror': 'onCloseErrorIndicator'
        "click a[target='_system']": 'openInSystemBrowser'


    initialize: ->
        document.addEventListener "menubutton", @onMenuButtonClicked, false
        document.addEventListener "searchbutton", @onSearchButtonClicked, false
        document.addEventListener "backbutton", @onBackButtonClicked, false

        @listenTo app.init.replicator, 'change:inSync change:inBackup', =>

            inSync = app.init.replicator.get('inSync')
            inBackup = app.init.replicator.get('inBackup')
            @spinner.toggle inSync or inBackup

        OpEvents = 'change:inBackup change:backup_step change:backup_step_done'
        @listenTo app.init.replicator, OpEvents, _.debounce =>
            step = app.init.replicator.get 'backup_step'
            if step
                text = t step
                if app.init.replicator.get 'backup_step_total'
                    text += ": #{app.init.replicator.get 'backup_step_done'}"
                    text += "/#{app.init.replicator.get 'backup_step_total'}"
                @backupIndicator.text(text).parent().slideDown()
                @viewsPlaceholder.addClass 'has-subheader'
            else
                @backupIndicator.parent().slideUp()
                @viewsPlaceholder.removeClass 'has-subheader'
        , 100


    afterRender: ->
        log.debug 'afterRender'

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

        @errorIndicator = @container.find '#errorIndicator'
        @errorIndicator.parent().hide()
        @listenTo app.init, 'error', @showError

        @initIndicator = @container.find '#initIndicator'
        @initIndicator.parent().hide()
        @errorIndicator.parent().hide()
        @listenTo app.init, 'display', @showInitMessage
        @listenTo app.init, 'noDisplay', @hideInitMessage

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
        @refreshBackgroundColor()


    refreshBackgroundColor: ->
        color = _.result @currentView, 'bodyBackgroundColor', 'white'
        @container.css 'background-color', color


    setBackButton: (href, icon) =>
        @backButton.attr 'href', href
        @backButton.removeClass 'ion-home ion-ios7-arrow-back'
        @backButton.addClass 'ion-' + icon


    hideTitle: ->
        @$('#breadcrumbs').remove()
        @title.hide()
        @$('#bar-header').hide()
        @$('#viewsPlaceholder').removeClass('has-header')


    setTitle: (text) =>
        @$('#breadcrumbs').remove()
        @title.text text
        @title.show()
        @$('#bar-header').show()
        @$('#viewsPlaceholder').addClass('has-header')


    setBreadcrumbs: (path) ->
        @$('#breadcrumbs').remove()
        @$('#bar-header').show()
        @$('#viewsPlaceholder').addClass('has-header')
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
            @afterTransition(view)

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
                @afterTransition(view)


    afterTransition: (view) ->
        @currentView = view
        ionic.trigger 'resetScrollView',
            target: @ionicScroll.__container
        , true
        @ionicScroll.hintResize()
        @ionicScroll.scrollTo 0, 0, false, null
        @refreshBackgroundColor()
        autofocusField = @currentView.$('.auto-focus')
        if autofocusField.length
            setTimeout (-> autofocusField.trigger 'click' ), 1
            autofocusField.one 'click', -> autofocusField.focus()

        if @currentView.$el.hasClass 'wizard-step'
            @currentView.$el.css 'height', ''


    showInitMessage: (message) =>
        log.debug 'showInitMessage'
        @initIndicator.text t message
        @initIndicator.parent().slideDown()
        @viewsPlaceholder.addClass 'has-subheader'


    hideInitMessage: =>
        log.debug 'hideInitMessage'
        @initIndicator.parent().slideUp()
        @viewsPlaceholder.removeClass 'has-subheader'


    showError: (error) =>
        log.debug 'showError'
        msg = error.message or error.reason or error
        @errorIndicator.text t msg
        @errorIndicator.parent().slideDown()
        @viewsPlaceholder.addClass 'has-subheader'


    onCloseErrorIndicator: =>
        log.debug 'onCloseErrorIndicator'
        @errorIndicator.parent().slideUp()
        @viewsPlaceholder.removeClass 'has-subheader'
        app.init.trigger 'errorViewed'


    onMenuButtonClicked: =>
        @menu.reset()
        @controller.toggleLeft()


    onSearchButtonClicked: =>
        @onMenuButtonClicked()
        @$('#search-input').focus()


    onBackButtonClicked: (event) =>
        if @currentView.btnBackEnabled? and @currentView.btnBackEnabled is false
            @currentView.onBackButtonClicked event

        # close menu first
        else if @isMenuOpen()
            @closeMenu()

        # app exit
        else if location.href.indexOf('#folder/') is (location.href.length - 8)
            if window.confirm t "confirm exit message"
                navigator.app.exitApp()

        else
            window.history.back()


    openInSystemBrowser: (e) ->
        window.open e.currentTarget.href, '_system', ''
        e.preventDefault()
        return false
