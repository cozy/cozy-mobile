BaseView = require '../lib/base_view'
showLoader = require './loader'

module.exports = class ConfigView extends BaseView

    tagName: 'a'
    template: require '../templates/folder_line'
    events:
        'click': 'onClick'

    className: 'item item-icon-left item-icon-right'

    initialize: =>
        @listenTo @model, 'change', @render

    onClick: =>
        if @model.get('docType') is 'Folder'
            path = @model.get('path') + '/' + @model.get('name')
            app.router.navigate "#folder#{path}", trigger: true
        else
            @loader = showLoader 'downloading binary'
            app.replicator.getBinary @model.attributes, (err, url) =>
                return @onError err if err
                ExternalFileUtil.openWith url, '', undefined, @afterOpen, @onError

    afterOpen: =>
        @model.set incache: true
        @loader.hide()
        @loader.$el.remove()

    onError: (e) =>
        @loader.hide()
        @loader.$el.remove()
        alert(e)
