# This view is reponsible to handle ionic complexities :
# - scrolling
# - sliding transitions

BaseView = require '../lib/base_view'
FolderView = require './folder'
Menu = require './menu'

module.exports = class Layout extends BaseView

    template: require '../templates/layout'

    events: ->
        # 'click #btn-back': 'onBackButtonClicked'
        'click #btn-menu': 'onMenuButtonClicked'

    afterRender: ->
        @menu = new Menu()
        @menu.render()
        @$el.append @menu.$el

        @container = @$('#container')
        @viewsPlaceholder = @$('#viewsPlaceholder')
        @viewsBlock = $('<div class="scroll"></div>')

        @viewsPlaceholder.append @viewsBlock

        @backButton = @container.find '#btn-back'
        @menuButton = @container.find '#btn-menu'

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


    closeMenu: =>
        @controller.toggleLeft false

    setBackButton: (href, icon) =>
        @backButton.attr 'href', href
        @backButton.removeClass 'ion-home ion-ios7-arrow-back'
        @backButton.addClass 'ion-' + icon

    transitionTo: (view, type) ->
        @closeMenu()
        $next = view.render().$el

        if @currentView instanceof FolderView and view instanceof FolderView
            type = if @currentView.isParentOf(view) then 'left' else 'right'
        else
            type = 'none'

        if type is 'none' # no animation
            @currentView?.remove()
            @viewsBlock.empty().append $next
            @ionicScroll.hintResize()
            @currentView = view
        else

            nextClass = if type is 'left' then 'sliding-next' else 'sliding-prev'
            currClass = if type is 'left' then 'sliding-prev' else 'sliding-next'

            $next.addClass nextClass
            @viewsBlock.append $next
            $next.width() # force reflow

            @currentView.$el.addClass currClass
            $next.removeClass nextClass

            transitionend = 'webkitTransitionEnd otransitionend oTransitionEnd msTransitionEnd transitionend'
            $next.one transitionend, =>
                @currentView.remove()
                @currentView = view

    onMenuButtonClicked: ->
        @menu.reset()
        @controller.toggleLeft()