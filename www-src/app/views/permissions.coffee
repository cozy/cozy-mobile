BaseView = require '../lib/base_view'

log = require('/lib/persistent_log')
    prefix: "PermissionsView"
    date: true

module.exports = class PermissionsPickerView extends BaseView

    className: 'list'
    template: require '../templates/permissions'

    events: ->
        'click #btn-save': 'doNext'
        'click #btn-back': 'doBack'

    getRenderData: ->
        return permissions: app.replicator.permissions

    doBack: ->
        app.router.navigate 'login', trigger: true

    doNext: ->
        app.router.navigate 'device-name-picker', trigger: true
