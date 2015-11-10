app = require 'application'
FolderView = require './views/folder'
LoginView = require './views/login'
PermissionsView = require './views/permissions'
DeviceNamePickerView = require './views/device_name_picker'
FirstSyncView = require './views/first_sync'
ConfigView = require './views/config'
FolderCollection = require './collections/files'

log = require('/lib/persistent_log')
    prefix: "replicator"
    date: true

module.exports = class Router extends Backbone.Router

    routes:
        'folder/*path'                    : 'folder'
        'search/*query'                   : 'search'
        'login'                           : 'login'
        'permissions'                     : 'permissions'
        'device-name-picker'              : 'deviceNamePicker'
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
        collection.search (err) =>
            if err
                log.error err.stack
                return alert(err)

            $('#search-input').blur() # close keyboard

    login: ->
        app.layout.setTitle(t('setup') + '1/4')
        $('#btn-menu, #btn-back').hide()
        @display new LoginView()

    permissions: ->
        app.layout.setTitle(t('setup') + '2/4')
        $('#btn-menu, #btn-back').hide()
        @display new PermissionsView()


    deviceNamePicker: ->
        app.layout.setTitle(t('setup') + '3/4')
        $('#btn-menu, #btn-back').hide()
        @display new DeviceNamePickerView()

    firstSync: ->
        app.layout.setTitle t 'setup end'
        $('#btn-menu, #btn-back').hide()
        @display new FirstSyncView()

    config: ->
        console.log "router.config"
        $('#btn-back').hide()
        title = if app.isFirstRun then (t('setup') + '4/4') else t 'config'
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
