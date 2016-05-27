log = require('./persistent_log')
    prefix: "toast"
    date: true


module.exports =


    info: (msg, duration = 5000) ->
        options = @_getDefaultOptions()
        options.message = t msg
        options.duration = duration
        @display options


    valid: (msg, duration = 5000) ->
        options = @_getDefaultOptions()
        options.message = t msg
        options.duration = duration
        options.styling.backgroundColor = '#68a581'
        @display options


    warn: (msg, duration = 5000) ->
        options = @_getDefaultOptions()
        options.message = t msg
        options.duration = duration
        options.styling.backgroundColor = '#ffa500'
        @display options


    error: (msg, duration = 5000) ->
        options = @_getDefaultOptions()
        options.message = t msg
        options.duration = duration
        options.styling.backgroundColor = '#e13a36'
        @display options


    hide: ->
        window.plugins.toast.hide()


    display: (options) ->
        if app.name is 'APP' and app.state isnt 'pause'
            window.plugins.toast.showWithOptions options


    _getDefaultOptions: ->
        position: "bottom"
        addPixelsY: -200
        styling:
            cornerRadius: 30
