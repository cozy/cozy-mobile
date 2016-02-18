app = require './application'
FolderView = require './views/folder'
LoginWizard = require './views/login'
PermissionsWizard = require './views/permissions_wizard'
PermissionsView = require './views/permissions'
FirstSyncView = require './views/first_sync'
ConfigView = require './views/config'
FolderCollection = require './collections/files'

log = require('./lib/persistent_log')
    prefix: "replicator"
    date: true

module.exports = class Router extends Backbone.Router

    routes:
        'folder/*path'                    : 'folder'
        'search/*query'                   : 'search'
        'login/*step'                     : 'login_wizard'
        'permissions/*step'               : 'permissions_wizard' # install
        'permissions'                     : 'permissions' # after change
        'first-sync'                      : 'firstSync'
        'config'                          : 'config'

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
                return alert(err)

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

    permissions: ->
        app.layout.setTitle(t('setup') + ' 2/4')
        $('#btn-menu, #btn-back').hide()
        @display new PermissionsView()

    config: ->
        $('#btn-back').hide()
        title = if app.isFirstRun then (t('setup') + ' 4/4') else t 'config'
        app.layout.setTitle title
        @display new ConfigView()


    display: (view) ->
        app.layout.transitionTo view

    forceRefresh: ->
        col = app.layout.currentView?.collection
        if col?.path is null then path = ''
        else if col?.path isnt undefined then path = col.path
        else return

        delete FolderCollection.cache[path]
        col.fetch()
