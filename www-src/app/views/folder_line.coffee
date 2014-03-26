BaseView = require '../lib/base_view'

module.exports = class ConfigView extends BaseView

    tagName: 'a'
    className: 'item item-icon-left'
    attributes: ->
        path = @model.get('path') + '/' + @model.get('name')
        return href: "#folder#{path}"
    template: require '../templates/folder_line'