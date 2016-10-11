BaseView = require './layout/base_view'

module.exports = class BreadcrumbsView extends BaseView

    id: 'breadcrumbs'
    template: require '../templates/breadcrumbs'

    initialize: (options) ->
        if options.path?
            @folder =
                name: options.path.split('/')[-1..-1][0]
                path: options.path

    getRenderData: ->
        return hasFolder: @folder?, folder: @folder

    afterRender: ->
        if @folder
            @$('#crumbs').show()
            @$('.home .arrow').show()
        else
            @$('#crumbs').hide()
            @$('.home .arrow').hide()
        return @
