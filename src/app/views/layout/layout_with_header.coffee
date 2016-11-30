Layout = require './layout'
Header = require './header'
FileViewer = require '../file_viewer'
FirstReplication = require '../../lib/first_replication'


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
        importProgress: '.import-state .determinate'
        importInfoText: '.import-state .info'


    initialize: ->
        super
        @header = new Header()
        @firstReplication = new FirstReplication()
        @firstReplication.addProgressionView (progression, total) =>
            percentage = progression * 100 / (total * 2)
            @importProgress.css 'width', "#{percentage}%"
        @listenTo @firstReplication, "change:queue", (object, task) =>
            if task
                @importInfoText.text t 'config_loading_' + task
                $('body').addClass 'import'
            else
                $('body').removeClass 'import'
                @importProgress.css 'width', "0%"
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


    getRenderData: ->
        running: @firstReplication.isRunning()
        taskName: @firstReplication.getTaskName()


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
