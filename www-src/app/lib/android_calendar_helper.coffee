log = require('lib/persistent_log')
    prefix: "android calendar helper"
    date: true

# Tools to convert contact from cordova to cozy, and from cozy to cordova.

DATE_FORMAT = 'YYYY-MM-DD'
AMBIGUOUS_DT_FORMAT = 'YYYY-MM-DD[T]HH:mm:00.000'
UTC_DT_FORMAT = 'YYYY-MM-DD[T]HH:mm:00.000[Z]'

ATTENDEE_STATUS_2_ANDROID =
    ACCEPTED: 1 # ATTENDEE_STATUS_ACCEPTED
    DECLINED: 2 # ATTENDEE_STATUS_DECLINED
    'INVITATION-NOT-SENT': 4 # ATTENDEE_STATUS_TENTATIVE
    'NEEDS-ACTION': 3 # ATTENDEE_STATUS_INVITED
    # 0 # ATTENDEE_STATUS_NONE

ATTENDEE_STATUS_2_COZY = _.invert ATTENDEE_STATUS_2_ANDROID

REMINDERS_METHOD_2_ANDROID =
            EMAIL: 2 # METHOD_EMAIL
            DISPLAY: 1 # METHOD_ALERT

REMINDERS_METHOD_2_COZY = _.invert REMINDERS_METHOD_2_ANDROID


module.exports = ACH =

    calendar2Android: (calendar) ->
        android =
            account_name: calendar.accountName
            account_type: calendar.accountType
            ownerAccount: calendar.accountName
            name: calendar.name.replace /\s/g, ''
            calendar_displayName: calendar.name
            calendar_color: parseInt(calendar.color.replace(/[^0-9A-Fa-f]/g, '')
                , 16)
            # No specific needs (?)
            #calendar_timezone: null

            # http://developer.android.com/reference/android/provider/
            # CalendarContract.CalendarColumns.html#CALENDAR_ACCESS_LEVEL
            calendar_access_level: 700
            sync_events: 1
            # METHOD_ALERT, METHOD_EMAIL,METHOD_ALARM
            allowedReminders: "1,2,4"
            allowedAvailability: "0" # Deactivated.
            allowedAttendeeTypes: "0" # Deactivated.

        return android


    event2Android: (cozy, calendarsIds) ->
        # Android
        allDay = undefined # 1 == allday
        dtstart = undefined # Unix millisecond timestamp
        dtend = undefined # Unix millisecond timestamp
        eventTimezone = 'UTC'

        if cozy.start.length is 10 # Allday
            allDay = 1

        if cozy.rrule?
            eventTimezone = cozy.timezone
            duration = moment(cozy.end).diff cozy.start
            duration = moment.duration duration
            duration = "P#{duration.asSeconds()}S"
            dtstart = moment.tz(cozy.start, cozy.timezone).format 'x'

        else
            dtstart = moment(cozy.start).format 'x'
            dtend = moment(cozy.end).format 'x'

        # attendees


        attendees = cozy.attendees.map (attendee) ->
            android =
                #_id: automatically set by the android plugin
                #event_id: automatically set by the android plugin
                #attendeeName: # not in cozy's format
                attendeeEmail: attendee.email
                attendeeRelationship: 0 # deactivated
                attendeeType: 0 # deactivated
                attendeeStatus: ATTENDEE_STATUS_2_ANDROID[attendee.status] or 0
                # Z: won't keep link to contact id (?)
            return android

        # reminders



        iCalDuration2Minutes = (s) ->
            # TODO use moment.duration (but look sensitive.)
            minutes = 0
            parts = s.match /(\d+)[WDHMS]/g
            for part in parts
                number = parseInt part.slice 0, part.length - 1
                switch part[part.length - 1]
                    when 'M' then minutes += number
                    when 'H' then minutes += number * 60
                    when 'D' then minutes += number * 60 * 24
                    when 'W' then minutes += number * 60 * 24 * 7

            return minutes

        reminders = cozy.alarms.map (alarm) ->
            android =
                minutes: iCalDuration2Minutes alarm.trigg
                method: REMINDERS_METHOD_2_ANDROID[alarm.action] or 0


        android =
            # _id
            calendar_id: calendarsIds[cozy.tags[0]]
            #organizer: undefined
            title: cozy.description
            eventLocation: cozy.place
            description: cozy.details
            dtstart: dtstart
            dtend: dtend
            duration: duration
            eventTimezone: eventTimezone
            allDay: allDay
            rrule: cozy.rrule
        # "accessLevel": 0,
        # "availability": 0,
        # "guestsCanModify": 0,
        # "guestsCanInviteOthers": 1,
        # "guestsCanSeeGuests": 1,
        # "dirty": 0,
            _sync_id: cozy._id
            sync_data2: cozy._rev
            sync_data5: cozy.lastModification
            attendees: attendees
            reminders: reminders

        return android


    event2Cozy: (android, calendarNames, cozy) ->


        start = undefined
        end = undefined
        timezone = undefined

        if android.rrule
            startMoment = moment.tz android.dtstart, android.eventTimezone

            duration = parseInt android.duration.replace /[^\d]/g, ''
            endMoment = moment startMoment
            endMoment = endMoment.add duration, 'seconds'
        else
            startMoment = moment android.dtstart
            endMoment = moment android.dtend

        if android.allDay
            start = startMoment.format DATE_FORMAT
            end = endMoment.format DATE_FORMAT

        else if android.rrule
            timezone = android.eventTimezone
            start = startMoment.format AMBIGUOUS_DT_FORMAT
            end = endMoment.format AMBIGUOUS_DT_FORMAT

        else
            start = startMoment.format UTC_DT_FORMAT
            end = endMoment.format UTC_DT_FORMAT


        attendees = android.attendees.map (attendee) ->
            if cozy? and cozy.attendees? and cozy.attendees.length isnt 0
                cozyAttendee = cozy.attendees.filter (cozyAttendee) ->
                    cozyAttendee.email is attendee.attendeeEmail
                cozyAttendee = cozyAttendee[0]

                status = ATTENDEE_STATUS_2_COZY[attendee.attendeeStatus]
                if status
                    cozyAttendee.status = status

                return cozyAttendee

            else
                transcripted =
                    key: random.randomString()
                    status: ATTENDEE_STATUS_2_COZY[attendee.attendeeStatus] or \
                            'NEEDS-ACTION'
                    email: attendee.attendeeEmail


        alarms = android.reminders.map (reminder) ->
            action = REMINDERS_METHOD_2_COZY[reminder.method] or 'DISPLAY'
            trigg = moment.duration reminder.minutes, 'minutes'
            trigg = '-' + JSON.stringify trigg

            return { action, trigg }

        event =
            docType: 'event'
            start: start
            end: end
            place: android.eventLocation
            description: android.title
            details: android.description
            rrule: android.rrule
            tags: [calendarNames[android.calendar_id]]
            attendees: attendees
            timezone: timezone
            alarms: alarms

            created: new Date().toISOString()
            lastModification: new Date().toISOString()

        # Update scenario.
        if cozy?
            tags = cozy.tags
            tags[0] = event.tags[0]

            created = cozy.created
            event = _.extend cozy, event

            event.tags = tags
            event.created = created

        return event