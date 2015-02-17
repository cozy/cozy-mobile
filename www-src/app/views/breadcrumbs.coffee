BaseView = require '../lib/base_view'

module.exports = class BreadcrumbsView extends BaseView

    id: 'breadcrumbs'
    template: require '../templates/breadcrumbs'
    itemview: require '../templates/breadcrumbs_element'

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
        for folder in @collection
            @$('#crumbs ul').append @itemview model: folder
        @

    scrollLeft: ->
        @$('#crumbs').scrollLeft $('#crumbs').outerWidth()


