log = require('./persistent_log')
    prefix: "toast"
    date: true


module.exports =


    info: (msg, duration = 5000) ->
        if app.name is 'APP' and app.state isnt 'pause'
            window.plugins.toast.showWithOptions
                message: t msg
                duration: duration
                position: "bottom"
                addPixelsY: -40


    hide: ->
        window.plugins.toast.hide()
