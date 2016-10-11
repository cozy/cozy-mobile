BaseView = require './base_view'
pathHelper = require '../../lib/path'
logSender = require '../../lib/log_sender'
log = require('../../lib/persistent_log')
    prefix: "Header"
    date: true


module.exports = class Header extends BaseView


    template: require '../../templates/layout/header'
    refs:
        menuButton: '#menuButton'
        searchInput: '#searchInput'
        searchForm: '#searchForm'
        headerDiv: '#header'


    initialize: ->
        @config ?= app.init.config
        @router ?= app.router
        @displaySender = 0


    events: ->
        'click .toggleSearch': 'toggleSearch'
        'submit #searchForm': 'searchSubmit'
        'click #displaySender': 'displaySender'
        'click #senderBtn': -> logSender.send()


    hide: ->
        @headerDiv.hide()


    show: ->
        @headerDiv.show()


    update: (options) ->
        @displaySearch = false #options.displaySearch
        if options.path
            @parentPath = pathHelper.getDirName options.path
            @title = pathHelper.getFileName options.path
            @title = 'files' if @parentPath is '' and @title is ''
            @path = options.path
        @title = options.title if options.title

        @render()


    getRenderData: ->
        parentPath: @parentPath
        title: @title
        displaySearch: @displaySearch
        appVersion: @config.get 'appVersion'
        userUrl: @config.get 'cozyURL'
        deviceName: @config.get 'deviceName'
        displayRender: @displaySender > 1


    toggleSearch: (event) ->
        console.log event
        nav = $('.header-file')
        nav.toggleClass 'search-open'
        if nav.hasClass 'search-open'
            setTimeout =>
                @searchInput.focus()
            , 100


    searchSubmit: (event) ->
        if @searchInput.val()
            @router.navigate '#search/' + @searchInput.val()
        return false


    displaySender: ->
        @displaySender++
        @render()


    afterRender: ->
        setTimeout =>
            if $('.drag-target').length > 0
                @menuButton.sideNav('destroy')
                setTimeout =>
                    @menuButton.sideNav()
                , 100
            else
                @menuButton.sideNav()
        , 100