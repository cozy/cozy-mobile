BaseView = require '../lib/base_view'

module.exports = class ConfigView extends BaseView

    template: -> """
        <button id="redbtn">RED BUTTON</button>
        <button id="greenbtn">GREEN BUTTON</button>
    """

    events: ->
        'click #redbtn': 'redBtn'
        'click #greenbtn': 'greenBtn'

    redBtn: ->
        app.replicator.destroyDB (err) =>
            return @displayError err.message, '#redbtn' if err

            $('#redbtn').text 'DONE'

    greenBtn: ->
        app.replicator.startSync (err) =>
            return @displayError err.message, '#greenbtn' if err

            $('#greenbtn').text 'DONE'

    displayError: (text, field) ->
        @error.remove() if @error
        @error = $('<div>').addClass('button button-full button-energized')
        @error.text text
        @$(field).before @error


