Layout = require './layout'
Header = require './header'
FileViewer = require '../file_viewer'


log = require('../../lib/persistent_log')
    prefix: "LayoutWithHeader"
    date: true


module.exports = class LayoutWithHeader extends Layout


    id: 'layout-with-menu'
    template: require '../../templates/layout/layout_with_header'
    refs:
        headerContainer: '#headerContainer'
        contentContainer: '#contentContainer'
        menuContainer: '#menuContainer'


    initialize: ->
        super
        @header = new Header()
        @views = []
        @router = app.router
        @alredyLoad = false


    afterRender: ->
        @headerContainer.html @header.render().$el


    updateHeader: (options) ->
        @header.update options


    showHeader: ->
        @header.show()


    hideHeader: ->
        @header.hide()


    display: (@view) ->
        log.info 'display'

        @oldView = @currentView
        @currentView = @view

        @currentView.backExit = true if @oldView is undefined

        if @currentView.append
            @views.push @currentView
            @contentContainer.append @currentView.render().$el
        else
            for @view in @views
                @view.destroy()
            @views.push @currentView
            @contentContainer.html @currentView.render().$el


    goBack: ->
        @oldView = @views.pop()
        @oldView.destroy()
        @back = false
        @currentView = @views[@views.length - 1]
        options =
            path: @currentView.options.path or 'files'
            displaySearch: true
        @updateHeader options
        if @views.length > 1
            @oldView = @views[@views.length - 2]
        else
            @oldView = undefined


    onBackButtonClicked: (event) =>
        if @currentView.backExit
            if window.confirm t "confirm exit message"
                navigator.app.exitApp()
        else
            if @currentView instanceof FileViewer
                @goBack()
                @router.navigate 'folder' + @currentView.path, trigger: false
            else
                @back = true
                window.history.back()
