BaseView = require '../layout/base_view'
urlValidator = require '../../lib/url_validator'


module.exports = class Url extends BaseView


    className: 'page'
    template: require '../../templates/onboarding/url'
    refs:
        inputUrl: '#input-url'
        buttonUrl: '#btn-url'
        content: '.wizard-step'


    initialize: (@config) ->
        @config ?= app.init.config
        @cozyUrl = @config.get 'cozyURL'
        @error = ''


    getRenderData: ->
        error: @error
        cozyUrl: @cozyUrl


    events: ->
        'blur #input-url': 'onURLBlur'
        'change #input-url': -> @error = '' if @error
        'click #btn-url': 'validUrl'


    onURLBlur: ->
        @cozyUrl = @inputUrl.val()
        return unless @cozyUrl
        @inputUrl.val urlValidator.cleanUrl @inputUrl.val()
        @cozyUrl = @inputUrl.val()
        unless urlValidator.validUrl @cozyUrl
            @error = "url invalid"
            @render()


    validUrl: (e) ->
        unless @inputUrl.val() is ''
            @inputUrl.val urlValidator.cleanUrl @inputUrl.val()
        @cozyUrl = @inputUrl.val()
        if urlValidator.validUrl @cozyUrl
            @config.setCozyUrl @cozyUrl
        else
            e.preventDefault()
            @error = "url invalid"
            @render()
