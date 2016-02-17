BaseView = require '../lib/base_view'
cleanUrl = require '../lib/cleanurl'

module.exports = class LoginView extends BaseView

    menuEnabled: false
    className: ->
        classes = ['wizard-step']
        classes.push @options.step if @options?.step
        classes.push 'error' if @error
        return classes.join ' '

    templates:
        'fWizardWelcome'  : require '../templates/wizard/welcome'
        'fWizardURL'      : require '../templates/wizard/url'
        'fWizardPassword' : require '../templates/wizard/password'

    afterRender : -> @$('input').focus()
    template: (data) -> @templates[@options.step](data)

    refs:
        inputURL      : '#input-url'
        inputPassword : '#input-password'

    events: ->
        'blur #input-url'        : 'onURLBlur'
        'change #input-url'      : 'onURLChange'
        'change #input-password' : 'onPasswordChange'
        'tap #btn-login'          : 'attemptLogin'
        'tap #btn-next'          : ->
            @onURLBlur()
            @options.fsm.trigger 'clickNext'
        'tap #btn-back-fsm'      : -> @options.fsm.trigger 'clickBack'
        'tap .wrong-url'         : -> @options.fsm.trigger 'clickBack'

    getRenderData: ->
        cozyURL: app.loginConfig?.cozyURL or ''
        password: app.loginConfig?.password or ''
        error: @error
        saving: @saving

    onURLChange: ->
        app.loginConfig.cozyURL = @inputURL.val()
        @setState 'error', null

    onPasswordChange: ->
        app.loginConfig.password = @inputPassword.val()
        @setState 'error', null

    onURLBlur: ->
        return unless @inputURL.val()
        @inputURL.val cleanUrl @inputURL.val()
        @onURLChange()

    attemptLogin: ->
        return null if @saving
        @onPasswordChange()
        @setState 'saving', true
        app.replicator.checkCredentials app.loginConfig, (error) =>
            @setState 'saving', false
            if error? then @setState 'error', error
            else app.init.trigger 'validCredentials'
