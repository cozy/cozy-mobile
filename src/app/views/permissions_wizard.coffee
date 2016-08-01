BaseView = require '../lib/base_view'

module.exports = class PermissionsWizard extends BaseView

    menuEnabled: false
    btnBackEnabled: false

    templates:
        'fWizardFiles'     : require '../templates/wizard/files'
        'fWizardContacts'  : require '../templates/wizard/contacts'
        'fWizardCalendars' : require '../templates/wizard/calendars'
        'fWizardPhotos'    : require '../templates/wizard/photos'

    className: ->
        classes = ['wizard-step']
        classes.push @options.step if @options?.step
        classes.push 'error' if @error
        return classes.join ' '

    template: (data) ->
        @templates[@options.step](data)

    events: ->
        'tap #btn-yep': => @onResponse true
        'tap #btn-nope': => @onResponse false

    onResponse: (value) ->
        config = window.app.init.config
        switch @options.step
            when 'fWizardContacts'  then config.set 'syncContacts',  value
            when 'fWizardCalendars' then config.set 'syncCalendars', value
            when 'fWizardPhotos'
                config.set 'syncImages', value
                config.set 'state', 'appConfigured'
            else # dont stock permission for Files, always true

        if device.platform is 'iOS'
            config.set 'state', 'appConfigured'
            return @options.fsm.trigger 'finish'

        @options.fsm.trigger 'clickNext'


    onBackButtonClicked: (event) =>
        if @options.step is 'fWizardFiles'
            if window.confirm t "confirm exit message"
                navigator.app.exitApp()
        else
            @options.fsm.trigger 'clickBack'
