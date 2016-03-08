BaseView = require '../lib/base_view'

module.exports = class PermissionsWizard extends BaseView

    menuEnabled: false
    className: ->
        classes = ['wizard-step']
        classes.push @options.step if @options?.step
        classes.push 'error' if @error
        return classes.join ' '

    templates:
        'fWizardFiles'     : require '../templates/wizard/files'
        'fWizardContacts'  : require '../templates/wizard/contacts'
        'fWizardCalendars' : require '../templates/wizard/calendars'
        'fWizardPhotos'    : require '../templates/wizard/photos'

    template: (data) -> @templates[@options.step](data)

    events: ->
        'tap #btn-yep': => @onResponse true
        'tap #btn-nope': => @onResponse false

    onResponse: (value) ->
        permissions = app.permissionsFromWizard ?= {}
        switch @options.step
            when 'fWizardContacts'  then permissions.syncContacts  = value
            when 'fWizardCalendars' then permissions.syncCalendars = value
            when 'fWizardPhotos'    then permissions.syncImages    = value
            else # dont stock permission for Files, always true

        @options.fsm.trigger 'clickNext'
