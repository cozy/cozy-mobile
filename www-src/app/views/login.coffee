BaseView = require '../lib/base_view'

module.exports = class LoginView extends BaseView

    className: 'list'
    template: require '../templates/login'

    events: ->
        'click #btn-save': 'doSave'
        'click #input-pass': 'doComplete'
        "click a[target='_system']": 'openInSystemBrowser'

    getRenderData: ->
        defaultValue = app.loginConfig  or cozyURL: '', password: ''
        return {defaultValue}

    afterRender: ->
        @$('.welcome').html t 'cozy welcome'
        @$('.welcome-message').html t 'cozy welcome message'
        @$('.no-account').html t 'cozy welcome no account'

    doComplete: ->
        url = @$('#input-url').val()
        if url.indexOf('.') is -1 and url.length > 0
            @$('#input-url').val url + ".cozycloud.cc"

    doSave: ->
        return null if @saving
        @saving = $('#btn-save').text()
        @error.remove() if @error

        url = @$('#input-url').val()
        pass = @$('#input-pass').val()

        # check all fields filled
        unless url and pass
            return @displayError t 'all fields are required'

        # keep only the hostname
        if url[0..3] is 'http'
            url = url.replace('https://', '').replace('http://', '')
            @$('#input-url').val url

        # remove trailing slash
        if url[url.length-1] is '/'
            @$('#input-url').val url = url[..-2]

        config =
            cozyURL: url
            password: pass

        $('#btn-save').text t 'authenticating...'
        app.replicator.checkCredentials config, (error) =>
            return @displayError error if error?
            app.replicator.checkPlatformVersions (err) =>
                return @displayError err if err?

                app.loginConfig = config
                app.router.navigate 'permissions', trigger: true

    displayError: (text, field) ->
        $('#btn-save').text @saving
        @saving = false
        @error.remove() if @error
        text = t 'connection failure' if ~text.indexOf('CORS request rejected')
        @error = $('<div>').addClass('error-msg')
        @error.html text
        @$(field or '#btn-save').before @error

    openInSystemBrowser: (e) ->
        window.open e.currentTarget.href, '_system', ''
        e.preventDefault()
        return false
