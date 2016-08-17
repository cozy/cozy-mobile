BaseView = require '../lib/base_view'
urlValidator = require '../lib/url_validator'

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
        btnLogin      : '#btn-password'


    events: ->
        # welcome page
        'tap #btn-welcome'       : -> @options.fsm.trigger 'clickNext'
        # url page
        'blur #input-url'        : 'onURLBlur'
        'change #input-url'      : -> @setState 'error', null if @error
        'tap #btn-url'           : 'validUrl'
        # password page
        'tap #btn-back-fsm'      : -> @options.fsm.trigger 'clickBack'
        'tap #btn-back'          : -> @options.fsm.trigger 'clickBack'
        'change #input-password' : -> @setState 'error', null if @error
        'tap #btn-password'      : 'validLogin'



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


    getRenderData: ->
        @config = window.app.init.config
        cozyURL: @config.get 'cozyURL'
        password: @inputPassword?.val() or ''
        error: @error


    onURLBlur: ->
        return unless @inputURL.val()
        @inputURL.val urlValidator.cleanUrl @inputURL.val()
        @config.setCozyUrl @inputURL.val()


    validUrl: ->
        url = @inputURL.val()

        if urlValidator.validUrl url
            @options.fsm.trigger 'clickNext'
        else
            @setState 'error', "url invalid"


    validLogin: ->
        unless app.init.connection.isConnected()
            @setState 'error', 'connection disable'
            return

        @btnLogin.attr 'disabled', 'true'
        url = @config.get 'cozyURL'
        password = @inputPassword.val()
        return @setState 'error', "password help" if password is ''
        checkCredentials = window.app.init.replicator.checkCredentials
        checkCredentials url, password, (err) =>
            @btnLogin.removeAttr("disabled")
            if err
                @setState 'error', err
            else
                @config.set 'devicePassword', @inputPassword.val()
                app.init.trigger 'validCredentials'
