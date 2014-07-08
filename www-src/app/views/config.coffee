BaseView = require '../lib/base_view'

module.exports = class ConfigView extends BaseView

    template: -> """
        <button id="redbtn" class="button button-block button-assertive">Reset</button>
        <p>This will erase all cozy-files generated data on your device.</p>
    """

    events: ->
        'click #redbtn': 'redBtn'

    redBtn: ->
        if confirm "Are you sure ?"
            app.replicator.destroyDB (err) =>
                return @displayError err.message, '#redbtn' if err

                $('#redbtn').text 'DONE'
                window.location.reload(true);

    displayError: (text, field) ->
        @error.remove() if @error
        @error = $('<div>').addClass('button button-full button-energized')
        @error.text text
        @$(field).before @error


