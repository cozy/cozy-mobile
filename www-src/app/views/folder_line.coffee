BaseView = require '../lib/base_view'
showLoader = require './loader'

module.exports = class ConfigView extends BaseView

    tagName: 'a'
    className: 'item item-icon-left'
    template: require '../templates/folder_line'
    events:
        'click': 'onClick'

    onClick: =>
        if @model.get('docType') is 'Folder'
            path = @model.get('path') + '/' + @model.get('name')
            app.router.navigate "#folder#{path}", trigger: true
        else
            loader = showLoader 'downloading binary'
            xhr = app.replicator.getBinary @model.get('binary'), (err, url) ->
                loader.hide()
                return alert err.message if err
                # let the OS handle it
                window.open url, '_system'

            loader.$el.on 'click', ->
                xhr.abort()
                loader.hide()