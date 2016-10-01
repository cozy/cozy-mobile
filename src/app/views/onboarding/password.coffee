BaseView = require '../layout/base_view'
ConnectionHandler = require '../../lib/connection_handler'


module.exports = class Password extends BaseView


    className: 'page'
    template: require '../../templates/onboarding/password'
    refs:
        inputPassword: '#input-password'
        displayPassword: '#display-password'
        content: '.wizard-step'
        btnPassword: '#btn-password'



    initialize: (@error = '') ->
        @config ?= app.init.config
        @cozyUrl = @config.get 'cozyURL'
        @password = ''
        StatusBar.backgroundColorByHexString '#4DCEC5'
        @connectionHandler = new ConnectionHandler()

        if @error and @error.startsWith 'CORS request rejected'
            @error = 'connexion error'


    getRenderData: ->
        error: @error
        cozyUrl: @cozyUrl
        password: @password


    events: ->
        'click #display-password': 'toggleInputType'
        'click #btn-password': 'validPassword'
        'blur #input-password': 'changePassword'
        'change #input-password': 'changePassword'


    toggleInputType: ->
        if @displayPassword.is(':checked')
            @inputPassword.attr 'type', 'text'
        else
            @inputPassword.attr 'type', 'password'


    changePassword: ->
        @password = @inputPassword.val()
        @error = '' if @error


    validPassword: (e) ->
        e.preventDefault()
        @password = @inputPassword.val()

        unless @password
            @error = 'onboarding_password_empty'
            return @render()

        unless @connectionHandler.isConnected()
            @error = 'connection disable'
            return @render()

        app.router.checkCredentials @password
