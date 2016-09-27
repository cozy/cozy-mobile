BaseView = require '../layout/base_view'


module.exports = class Permission extends BaseView



    className: 'page'
    templates:
        'files': require '../../templates/onboarding/permission_files'
        'contacts': require '../../templates/onboarding/permission_contacts'
        'calendars': require '../../templates/onboarding/permission_calendars'
        'photos': require '../../templates/onboarding/permission_photos'
    refs:
        noBtn: '#btn-nope'
        yesBtn: '#btn-yep'


    template: (data) ->
        @templates[@step](data)


    initialize: (@step) ->
        @config ?= app.init.config
        @router ?= app.router
        @platform ?= device.platform


    events: ->
        'click #btn-yep': => @setPermission true
        'click #btn-nope': => @setPermission false


    setPermission: (value) ->
        switch @step
            when 'contacts'
                @config.set 'syncContacts', value
            when 'calendars'
                @config.set 'syncCalendars', value
            when 'photos'
                @config.set 'syncImages', value
            # dont stock permission for Files, always true

        route = switch @step
            when 'files' then 'permissions/contacts'
            when 'contacts' then 'permissions/calendars'
            when 'calendars' then 'permissions/photos'
            when 'photos' then 'folder/'

        route = 'folder/' if @platform is 'iOS'

        if route is 'folder/' and 'syncCompleted' isnt @config.get 'state'
            @config.set 'state', 'appConfigured'

        @router.navigate route, trigger: true
