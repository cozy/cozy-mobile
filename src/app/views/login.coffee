BaseView = require '../lib/base_view'

module.exports = class LoginView extends BaseView

    menuEnabled: false
    btnBackEnabled: false

    templates:
        'fWizardWelcome'  : require '../templates/wizard/welcome'
        'fWizardURL'      : require '../templates/wizard/url'
        'fWizardPassword' : require '../templates/wizard/password'

    refs:
        inputURL      : '#input-url'
        inputPassword : '#input-password'
        btnLogin      : '#btn-login'


    remove: ->
        $('body').css 'background-color', @prevBodyBgColor
        super


    className: ->
        classes = ['wizard-step']
        classes.push @options.step if @options?.step
        classes.push 'error' if @error
        return classes.join ' '

    template: (data) ->
        @templates[@options.step](data)

    afterRender : ->
        @$('input').focus()
        app.layout.refreshBackgroundColor()

    bodyBackgroundColor: ->
        @$el.css 'background-color'


    events: ->
        'blur #input-url'        : 'onURLBlur'
        'blur #input-password'   : 'onPasswordBlur'
        'change #input-url'      : -> @setState 'error', null if @error
        'change #input-password' : -> @setState 'error', null if @error
        'tap #btn-login'         : 'attemptLogin'
        'tap #btn-next'          : ->
            @onURLBlur()
            @options.fsm.trigger 'clickNext'
        'tap #btn-back-fsm'      : -> @options.fsm.trigger 'clickBack'
        'tap .wrong-url'         : -> @options.fsm.trigger 'clickBack'

    getRenderData: ->
        @config = window.app.init.config
        cozyURL: @config.get 'cozyURL'
        password: @inputPassword?.val() or ''
        error: @error

    onURLBlur: ->
        return unless @inputURL.val()
        @inputURL.val @_cleanUrl @inputURL.val()
        @config.setCozyUrl @inputURL.val()

    onPasswordBlur: ->
        @setState 'error', null if @error


    attemptLogin: ->
        @btnLogin.attr 'disabled', 'true'
        url = @config.get 'cozyURL'
        password = @inputPassword.val()
        checkCredentials = window.app.init.replicator.checkCredentials
        checkCredentials url, password, (err) =>
            @btnLogin.removeAttr("disabled")
            if err
                @setState 'error', err
            else
                @config.set 'devicePassword', @inputPassword.val()
                app.init.trigger 'validCredentials'


    _cleanUrl: (url) ->
        # add .cozycloud.cc if the user only input name
        if url.indexOf('.') is -1 and url.length > 0
            url = url + ".cozycloud.cc"

        # Add http on the hostname
        if url[0..3] isnt 'http'
            url = 'https://' + url

        # remove trailing slash
        if url[url.length-1] is '/'
            url = url[..-2]

        return url
