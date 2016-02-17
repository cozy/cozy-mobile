module.exports = class BaseView extends Backbone.View

    template: ->

    initialize: (@options) ->

    getRenderData: ->
        model: @model?.toJSON()

    render: ->
        @beforeRender()
        @$el.html @template(@getRenderData())
        @bindRefs() if @refs
        @$el.prop 'className', @className() if typeof @className is 'function'
        @afterRender()
        @

    bindRefs: ->
        for ref, selector of @refs
            @[ref] = @$ selector

    setState: (key, value) ->
        clearTimeout @dirtyTimeout
        @[key] = value
        @dirtyTimeout = setTimeout @render.bind(@), 1

    beforeRender: ->

    afterRender: ->

    destroy: ->
        @undelegateEvents()
        @$el.removeData().unbind()
        @remove()
        Backbone.View::remove.call @
