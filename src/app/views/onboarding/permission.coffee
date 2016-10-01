BaseView = require '../layout/base_view'
FirstReplication = require '../../lib/first_replication'
CheckPermission = require '../../lib/permission'


module.exports = class Permission extends BaseView



    className: 'page'
    templates:
        'files': require '../../templates/onboarding/permission_files'
        'contacts': require '../../templates/onboarding/permission_contacts'
        'calendars': require '../../templates/onboarding/permission_calendars'
        'photos': require '../../templates/onboarding/permission_photos'
    colors:
        'files': '#9169F2'
        'contacts': '#FD7461'
        'calendars': '#34D882'
        'photos': '#FFAE5F'
    refs:
        noBtn: '#btn-nope'
        yesBtn: '#btn-yep'


    template: (data) ->
        @templates[@step](data)


    initialize: (@step) ->
        if @step is 'files'
            @backExit = true
        else
            @backExit = false
        @config ?= app.init.config
        @router ?= app.router
        @platform ?= device.platform
        StatusBar.backgroundColorByHexString @colors[@step]
        @firstReplication = new FirstReplication()
        @checkPermission = new CheckPermission()



    events: ->
        'click #btn-yep': => @setPermission true
        'click #btn-nope': => @setPermission false


    setPermission: (value) ->
        route = switch @step
            when 'files' then 'permissions/contacts'
            when 'contacts' then 'permissions/calendars'
            when 'calendars' then 'permissions/photos'
            when 'photos' then 'folder/'

        route = 'folder/' if @platform is 'iOS'

        if route is 'folder/'
            StatusBar.backgroundColorByHexString '#33A6FF'
            if 'syncCompleted' isnt @config.get 'state'
                @config.set 'state', 'appConfigured'

        if @step is 'files'
            return @router.navigate route, trigger: true

        next = (status) =>
            switch @step
                when 'contacts'
                    @config.set 'syncContacts', status
                when 'calendars'
                    @config.set 'syncCalendars', status
                when 'photos'
                    @config.set 'syncImages', status

            if status and @step is 'contacts' or @step is 'calendars'
                @firstReplication.addTask 'contacts'

            @router.navigate route, trigger: true

        @checkPermission.checkPermission @step, next, next
