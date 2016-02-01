random = require '../../lib/random'
log = require('../../lib/persistent_log')
    prefix: "CozyToAndroidEvent"
    date: true

module.exports = class CozyToAndroidEvent

    # Tools to convert contact from cordova to cozy, and from cozy to cordova.
    DATE_FORMAT = 'YYYY-MM-DD'
    AMBIGUOUS_DT_FORMAT = 'YYYY-MM-DD[T]HH:mm:00.000'
    UTC_DT_FORMAT = 'YYYY-MM-DD[T]HH:mm:00.000[Z]'

    ATTENDEE_STATUS_2_ANDROID =
        'ACCEPTED':            1 # ATTENDEE_STATUS_ACCEPTED
        'DECLINED':            2 # ATTENDEE_STATUS_DECLINED
        'INVITATION-NOT-SENT': 4 # ATTENDEE_STATUS_TENTATIVE
        'NEEDS-ACTION':        3 # ATTENDEE_STATUS_INVITED
        #                      0 # ATTENDEE_STATUS_NONE

    ATTENDEE_STATUS_2_COZY = _.invert ATTENDEE_STATUS_2_ANDROID

    REMINDERS_METHOD_2_ANDROID =
        EMAIL:   2 # METHOD_EMAIL
        DISPLAY: 1 # METHOD_ALERT

    REMINDERS_METHOD_2_COZY = _.invert REMINDERS_METHOD_2_ANDROID

    transform: (cozyEvent, androidCalendar, androidEvent = undefined) ->
        log.info "transform"

        allDay = if cozyEvent.start.length is 10 then 1 else 0 # 1 == allday
        rrule = undefined
        dtstart = undefined # Unix millisecond timestamp
        dtend = undefined # Unix millisecond timestamp
        eventTimezone = 'UTC'

        if cozyEvent.rrule? and cozyEvent.rrule isnt ''
            rrule = cozyEvent.rrule
            # Europe/Paris is a stub for buggy docs.
            eventTimezone = cozyEvent.timezone or 'Europe/Paris'
            duration = moment(cozyEvent.end).diff cozyEvent.start
            duration = moment.duration duration
            duration = JSON.stringify duration
            duration = duration.replace /"/g, ''
            dtstart = parseInt moment.tz(cozyEvent.start, cozyEvent.timezone).format 'x'
        else # Punctual, datetime are in UTC timezone.
            dtstart = parseInt moment.tz(cozyEvent.start, 'UTC').format 'x'
            dtend = parseInt moment.tz(cozyEvent.end, 'UTC').format 'x'

        # attendees


        attendees = cozyEvent.attendees.map (attendee) ->
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

        reminders = cozyEvent.alarms.map (alarm) ->
            return \
                minutes: iCalDuration2Minutes alarm.trigg
                method: REMINDERS_METHOD_2_ANDROID[alarm.action] or 0 # DEFAULT

        return {
            _id: if androidEvent then androidEvent._id else undefined
            calendar_id: androidCalendar._id
            # organizer: undefined
            title: cozyEvent.description
            eventLocation: cozyEvent.place
            description: cozyEvent.details
            dtstart: dtstart
            dtend: dtend
            duration: duration
            eventTimezone: eventTimezone
            allDay: allDay
            rrule: rrule
            # "accessLevel": 0,
            # "availability": 0,
            # "guestsCanModify": 0,
            # "guestsCanInviteOthers": 1,
            # "guestsCanSeeGuests": 1,
            # "dirty": 0,
            _sync_id: cozyEvent._id
            sync_data2: cozyEvent._rev
            sync_data5: cozyEvent.lastModification
            attendees: attendees
            reminders: reminders
        }

    reverseTransform: (androidEvent, androidCalendar, cozyEvent = undefined) ->
        log.info "reverseTransform"

        start = undefined
        end = undefined
        timezone = undefined

        if androidEvent.rrule? and androidEvent.rrule isnt ''
            startMoment = moment.tz androidEvent.dtstart, androidEvent.eventTimezone
            duration = ACH.android2Duration androidEvent.duration
            #duration = parseInt androidEvent.duration.replace /[^\d]/g, ''
            endMoment = moment startMoment
            endMoment = endMoment.add duration
        else
            startMoment = moment.tz androidEvent.dtstart, androidEvent.eventTimezone
            endMoment = moment.tz androidEvent.dtend, androidEvent.eventTimezone

        if androidEvent.allDay
            start = startMoment.format DATE_FORMAT
            # # Hack to help moving to the next day.
            # endMoment.add 10, 'seconds'
            end = endMoment.format DATE_FORMAT

        else if androidEvent.rrule
            timezone = androidEvent.eventTimezone
            start = startMoment.format AMBIGUOUS_DT_FORMAT
            end = endMoment.format AMBIGUOUS_DT_FORMAT

        else
            start = startMoment.toISOString()
            end = endMoment.toISOString()


        attendees = androidEvent.attendees.map (attendee) ->
            if cozyEvent? and cozyEvent.attendees? and cozyEvent.attendees.length isnt 0
                cozyAttendee = cozyEvent.attendees.filter (cozyAttendee) ->
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
                return transcripted

        if attendees
            attendees = attendees.filter (attendee) ->
                return attendee.attendeeEmail isnt androidCalendar.accountName


        alarms = androidEvent.reminders.map (reminder) ->
            action = REMINDERS_METHOD_2_COZY[reminder.method] or 'DISPLAY'
            trigg = moment.duration reminder.minutes * -1, 'minutes'
            trigg = JSON.stringify trigg
            trigg = trigg.replace /"/g, ''

            return { action, trigg }

        event =
            docType: 'event'
            start: start
            end: end
            place: androidEvent.eventLocation
            description: androidEvent.title
            details: androidEvent.description
            rrule: androidEvent.rrule
            tags: [androidCalendar.name]
            attendees: attendees
            timezone: timezone
            alarms: alarms

            created: new Date().toISOString()
            lastModification: new Date().toISOString()

        # Update scenario.
        if cozyEvent?
            tags = cozyEvent.tags
            tags[0] = event.tags[0]

            created = cozyEvent.created
            event = _.extend cozyEvent, event

            event.tags = tags
            event.created = created

        return event
