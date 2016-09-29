app = require './application'
FolderView = require './views/folder'
MediaPlayerView = require './views/media_player'
LoginWizard = require './views/login'
PermissionsWizard = require './views/permissions_wizard'
PermissionsView = require './views/permissions'
FirstSyncView = require './views/first_sync'
ConfigView = require './views/config'
FolderCollection = require './collections/files'
FileViewer = require './views/file_viewer'

Layout = require './views/layout/layout'
LayoutWithHeader = require './views/layout/layout_with_header'
WelcomeView = require './views/onboarding/welcome'
UrlView = require './views/onboarding/url'
PasswordView = require './views/onboarding/password'
CheckCredentialsView = require './views/onboarding/check_credentials'
PermissionsView = require './views/onboarding/permission'
ConfigView = require './views/config'

log = require('./lib/persistent_log')
    prefix: "router"
    date: true

module.exports = class Router extends Backbone.Router

    routes:
        'onboarding/welcome'              : 'welcome'
        'onboarding/url'                  : 'url'
        'onboarding/password'             : 'password'
        'onboarding/check'                : 'checkCredentials'
        'permissions/*step'               : 'permissions'
        'folder*path'                     : 'fileViewer'
        'media/*path'                     : 'media'

        'search/*query'                   : 'search'
        'login/*step'                     : 'login_wizard'
        'first-sync'                      : 'firstSync'
        'config'                          : 'config'


    init: (state) ->
        console.log 'state', state

        if state is 'syncCompleted' or state is 'appConfigured'
            @navigate 'folder/'
            return @fileViewer '/'

        @layout = new Layout()
        $('body').html @layout.render().el

        if state is 'deviceCreated'
            @permissions 'files'
        else
            @welcome()


    welcome: ->
        @layout.display new WelcomeView()


    url: ->
        @layout.display new UrlView()


    password: (error) ->
        @layout.display new PasswordView error


    checkCredentials: (password) ->
        @layout.display new CheckCredentialsView password


    permissions: (step) ->
        @layout.display new PermissionsView step


    fileViewer: (path) ->
        log.info 'foleViewer', path

        if @layout is undefined or not(@layout instanceof LayoutWithHeader)
            log.info 'create LayoutWithHeader'
            @layout = new LayoutWithHeader()
            $('body').html @layout.render().el
        return @layout.alredyLoad = false if @layout.alredyLoad
        if @layout.back
            @layout.goBack()
        else
            @layout.updateHeader path: path, displaySearch: true
            @layout.display new FileViewer path: path


    media: (path) ->
        @layout.display new MediaPlayerView path


    config: ->
        @layout.updateHeader title: 'config', displaySearch: false
        @layout.display new ConfigView()


    search: (query) ->
        @layout.updateHeader title: t('search') + ' "' + query + '"'
        @layout.display new SearchView query
        $('#btn-menu').show()
        $('#btn-back').hide()
        app.layout.setBackButton '#folder/', 'home'
        app.layout.setTitle t('search') + ' "' + query + '"'

        collection = new FolderCollection [], query: query
        @display new FolderView {collection}
        collection.search (err) ->
            if err
                log.error err.stack
                return navigator.notification.alert(err)

            $('#search-input').blur() # close keyboard









    folder: (path) ->
        $('#btn-menu').show()
        $('#btn-back').hide()
        app.layout.setBreadcrumbs path

        collection = new FolderCollection [], path: path
        @display new FolderView {collection},
        collection.fetch()
        collection.once 'fullsync', => @trigger 'collectionfetched'

    search: (query) ->
        $('#btn-menu').show()
        $('#btn-back').hide()
        app.layout.setBackButton '#folder/', 'home'
        app.layout.setTitle t('search') + ' "' + query + '"'

        collection = new FolderCollection [], query: query
        @display new FolderView {collection}
        collection.search (err) ->
            if err
                log.error err.stack
                return navigator.notification.alert(err)

            $('#search-input').blur() # close keyboard

    login_wizard: (step) ->
        app.layout.hideTitle()
        $('#btn-menu, #btn-back').hide()
        @display new LoginWizard {step: step, fsm: app.init}

    permissions_wizard: (step) ->
        app.layout.hideTitle()
        $('#btn-menu, #btn-back').hide()
        @display new PermissionsWizard {step: step, fsm: app.init}

    firstSync: ->
        app.layout.setTitle t 'setup end'
        $('#btn-menu, #btn-back').hide()
        @display new FirstSyncView()

#    permissions: ->
#        app.layout.setTitle(t('setup') + ' 2/4')
#        $('#btn-menu, #btn-back').hide()
#        @display new PermissionsView()
#
#    config: ->
#        $('#btn-back').hide()
#        title = if app.isFirstRun then (t('setup') + ' 4/4') else t 'config'
#        app.layout.setTitle title
#        @display new ConfigView()


    display: (view) ->
        app.layout.transitionTo view

    forceRefresh: ->
        col = app.layout?.currentView?.collection
        if col?.path is null then path = ''
        else if col?.path isnt undefined then path = col.path
        else return

        delete FolderCollection.cache[path]
        col.fetch()
