BaseView = require '../layout/base_view'


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

        if @error and @error.startsWith 'CORS request rejected'
            @error = 'CORS request rejected'


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
            @error = 'password empty'
            return @render()

        app.router.checkCredentials @password
