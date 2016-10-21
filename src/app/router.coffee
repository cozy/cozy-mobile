Layout = require './views/layout/layout'
LayoutWithHeader = require './views/layout/layout_with_header'

# onboarding
WelcomeView = require './views/onboarding/welcome'
UrlView = require './views/onboarding/url'
PasswordView = require './views/onboarding/password'
CheckCredentialsView = require './views/onboarding/check_credentials'
PermissionsView = require './views/onboarding/permission'

# others
FileViewer = require './views/file_viewer'
MediaPlayerView = require './views/media_player'
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
        'config'                          : 'config'


    init: (state) ->
        if state is 'appConfigured'
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

        unless @layout is undefined or @layout instanceof LayoutWithHeader
            @layout.destroy()
            @layout = undefined

        if @layout is undefined
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
        @layout.updateHeader title: t('config'), displaySearch: false
        @layout.display new ConfigView()
