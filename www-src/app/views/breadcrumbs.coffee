BaseView = require '../lib/base_view'

module.exports = class BreadcrumbsView extends BaseView

    id: 'breadcrumbs'
    template: require '../templates/breadcrumbs'
    itemview: require '../templates/breadcrumbs_element'

    events:
        'click #truncated': 'scrollRight'

    initialize: (options) ->
        if not options.path?
            @collection = []
        else
            reduction = options.path.split('/').reduce (agg, name) ->
                agg.path += '/' + name
                agg.collection.push
                    name: name
                    path: agg.path

                return agg
            ,   {collection: [], path: '' }
            @collection = reduction.collection

    # collection is a simple array, not a backbone collection
    afterRender: ->
        @crumbsElem = @$('#crumbs')
        if @collection.length is 0
            @toggleHomeEdge 'round'
            return @

        @toggleHomeEdge 'arrow'

        for folder in @collection
            @$('#crumbs ul').append @itemview model: folder

        @crumbsElem.scroll (ev) =>
            if ev.target.scrollLeft is 0
                @toggleHomeEdge 'arrow'
            else
                @toggleHomeEdge 'truncated'

        return @


    toggleHomeEdge: (edgeStyle)->
        switch edgeStyle
            when 'truncated'
                @$('.home .round').hide()
                @$('.home .arrow').show()
                @$('#truncated').show()
            when 'arrow'
                @$('.home .round').hide()
                @$('.home .arrow').show()
                @$('#truncated').hide()

            when 'round'
                @$('.home .round').show()
                @$('.home .arrow').hide()
                @$('#truncated').hide()


    scrollLeft: ->
        @crumbsElem.scrollLeft @crumbsElem.outerWidth()

    scrollRight: ->
        @crumbsElem.scrollLeft -20
