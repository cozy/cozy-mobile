Model = require './information.model'


module.exports = class Information extends Backbone.View


    template: require './information.template'


    initialize: ->
        @model = new Model()
        @listenTo @model, 'change', @render
        @listenTo @model, 'change:text', (object, text) ->
            if text is ''
                $('body').removeClass 'import'
            else
                $('body').addClass 'import'
        @


    render: ->
        @$el.html @template @model.toJSON()
        @


    hide: ->
        @model.set 'display', false


    show: ->
        @model.set 'display', true
