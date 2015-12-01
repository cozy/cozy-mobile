ACH = require 'lib/android_calendar_helper'

describe 'Unit tests', ->
    describe 'android2Duration', ->
        it "works with missing T", ->
            ACH.android2Duration('P3600S').asSeconds().should.eql 3600

describe 'Convert Cozy event to Android', ->
    calendarIds =
        "calendar 1": 58

    calendarNames = _.invert calendarIds

    describe 'PunctualEvent2Android', ->
        cozyEvent = jsonFixtures.event_punctual_cozy
        androidEvent = jsonFixtures.event_punctual_android

        obtained = ACH.event2Android cozyEvent, calendarIds
        it "calendar_id", ->
            obtained.calendar_id.should.eql androidEvent.calendar_id
        it "title", ->
            obtained.title.should.eql androidEvent.title
        it "eventLocation", ->
            obtained.eventLocation.should.eql androidEvent.eventLocation
        it "description", ->
            obtained.description.should.eql androidEvent.description
        it "dtstart", ->
            obtained.dtstart.should.eql androidEvent.dtstart
        it "dtend", ->
            obtained.dtend.should.eql androidEvent.dtend
        it "duration", ->
            expect(obtained.duration).to.be.undefined
        it "eventTimezone", ->
            expect(obtained.eventTimezone).to.be.undefined
        it "allDay", ->
            expect(obtained.allDay).to.be.undefined
        it "rrule", ->
            expect(obtained.rrule).to.be.undefined
        it "_sync_id", ->
            obtained._sync_id.should.eql androidEvent._sync_id
        it "sync_data2", ->
            obtained.sync_data2.should.eql androidEvent.sync_data2
        #it "sync_data5", ->
        #    obtained.sync_data5.should.eql androidEvent.sync_data5

        # Attendees
        it "attendees", ->
            obtained.attendees.should.be.empty
        it "reminders", ->
            obtained.reminders.length.should.eql androidEvent.reminders.length
            # To hard condition: keep order isn't necessary.

        it "reminder1", ->
            obtained.reminders[0].minutes.should.eql androidEvent.reminders[0].minutes
            obtained.reminders[0].method.should.eql androidEvent.reminders[0].method

        it "reminder2", ->
            obtained.reminders[1].minutes.should.eql androidEvent.reminders[1].minutes
            obtained.reminders[1].method.should.eql androidEvent.reminders[1].method

    describe 'PunctualEvent2Cozy', ->
        cozyEvent = jsonFixtures.event_punctual_cozy
        androidEvent = jsonFixtures.event_punctual_androidcreated

        obtained = ACH.event2Cozy androidEvent, calendarNames
        it "docType", ->
            obtained.docType.should.eql cozyEvent.docType
        it "start", ->
            obtained.start.should.eql cozyEvent.start

        it "end", ->
            obtained.end.should.eql cozyEvent.end
        it "place", ->
            obtained.place.should.eql cozyEvent.place
        it "description", ->
            obtained.description.should.eql cozyEvent.description
        it "details", ->
            obtained.details.should.eql cozyEvent.details
        it "rrule", ->
            expect(obtained.rrule).to.be.undefined
        it "tags", ->
            obtained.tags.should.eql cozyEvent.tags
        it "timezone", ->
            expect(obtained.timezone).to.be.undefined
        # it "created", ->
        #     obtained.created.should.eql cozyEvent.created

        # Attendees
        it "attendees", ->
            obtained.attendees.should.be.empty

        # Alarms
        it "alarms", ->
            obtained.alarms.length.should.eql cozyEvent.alarms.length
        it "alarms_1", ->

            # To hard condition: keep order isn't necessary.
            obtained.alarms[0].trigg.should.eql cozyEvent.alarms[0].trigg
            obtained.alarms[0].action.should.eql cozyEvent.alarms[0].action

        it "alarms_2", ->
            alarm2 = obtained.alarms[1]
            cozyAlarm2 = cozyEvent.alarms[1]
            # -PT24H' === '-P1D'
            moment.duration(alarm2.trigg).asMinutes()
                .should.eql moment.duration(cozyAlarm2.trigg).asMinutes()
            obtained.alarms[1].action.should.eql cozyEvent.alarms[1].action

    describe 'RecurringEvent2Android', ->
        cozyEvent = jsonFixtures.event_recurring_cozy
        androidEvent = jsonFixtures.event_recurring_android

        obtained = ACH.event2Android cozyEvent, calendarIds
        it "calendar_id", ->
            obtained.calendar_id.should.eql androidEvent.calendar_id
        it "title", ->
            obtained.title.should.eql androidEvent.title
        it "eventLocation", ->
            obtained.eventLocation.should.eql androidEvent.eventLocation
        it "description", ->
            obtained.description.should.eql androidEvent.description
        it "dtstart", ->
            obtained.dtstart.should.eql androidEvent.dtstart
        it "dtend", ->
            expect(obtained.dtend).to.be.undefined
        it "duration", ->
            moment.duration(obtained.duration).asSeconds()
                .should.eql ACH.android2Duration(androidEvent.duration).asSeconds()
        it "eventTimezone", ->
            obtained.eventTimezone.should.eql androidEvent.eventTimezone
        it "allDay", ->
            expect(obtained.allDay).to.be.undefined
        it "rrule", ->
            obtained.rrule.should.eql androidEvent.rrule
        it "_sync_id", ->
            obtained._sync_id.should.eql androidEvent._sync_id
        it "sync_data2", ->
            obtained.sync_data2.should.eql androidEvent.sync_data2
        #it "sync_data5", ->
        #    obtained.sync_data5.should.eql androidEvent.sync_data5

        # Attendees
        it "attendees", ->
            obtained.attendees.should.be.empty
        it "reminders", ->
            obtained.reminders.should.be.empty


    describe 'RecurringEvent2Cozy', ->
        cozyEvent = jsonFixtures.event_recurring_cozy
        androidEvent = jsonFixtures.event_recurring_android

        obtained = ACH.event2Cozy androidEvent, calendarNames
        it "docType", ->
            obtained.docType.should.eql cozyEvent.docType
        it "start", ->
            obtained.start.should.eql cozyEvent.start
        it "end", ->
            obtained.end.should.eql cozyEvent.end
        it "place", ->
            obtained.place.should.eql cozyEvent.place
        it "description", ->
            obtained.description.should.eql cozyEvent.description
        it "details", ->
            obtained.details.should.eql cozyEvent.details
        it "rrule", ->
            obtained.rrule.should.eql cozyEvent.rrule
        it "tags", ->
            obtained.tags.should.eql cozyEvent.tags
        it "timezone", ->
            obtained.timezone.should.eql cozyEvent.timezone
        # it "created", ->
        #     obtained.created.should.eql cozyEvent.created

        # Attendees
        it "attendees", ->
            obtained.attendees.should.be.empty

        # Alarms
        it "alarms", ->
            obtained.alarms.should.be.empty

    describe 'RecurringAllDayEvent2Android', ->
        cozyEvent = jsonFixtures.event_recurringallday_cozy
        androidEvent = jsonFixtures.event_recurringallday_android

        obtained = ACH.event2Android cozyEvent, calendarIds
        it "calendar_id", ->
            obtained.calendar_id.should.eql androidEvent.calendar_id
        it "title", ->
            obtained.title.should.eql androidEvent.title
        it "eventLocation", ->
            obtained.eventLocation.should.eql androidEvent.eventLocation
        it "description", ->
            obtained.description.should.eql androidEvent.description
        it "dtstart", ->
            obtained.dtstart.should.eql androidEvent.dtstart
        it "dtend", ->
            expect(obtained.dtend).to.be.undefined
        it "duration", ->
            moment.duration(obtained.duration).asSeconds()
            .should.eql ACH.android2Duration(androidEvent.duration).asSeconds()
        #TODO
        it "eventTimezone", ->
            expect(obtained.eventTimezone).to.be.undefined
        it "allDay", ->
            expect(obtained.allDay).to.be.undefined
        it "rrule", ->
            obtained.rrule.should.eql androidEvent.rrule
        it "_sync_id", ->
            obtained._sync_id.should.eql androidEvent._sync_id
        it "sync_data2", ->
            obtained.sync_data2.should.eql androidEvent.sync_data2
        #it "sync_data5", ->
        #    obtained.sync_data5.should.eql androidEvent.sync_data5

        # Attendees
        it "attendees", ->
            obtained.attendees.length.should.eql androidEvent.attendees.length

        it "attendee1", ->
            attendee = obtained.attendees[0]
            androidA = androidEvent.attendees[0]
            attendee.attendeeEmail.should.eql androidA.attendeeEmail
            attendee.attendeeRelationship.should.eql androidA.attendeeRelationship
            attendee.attendeeType.should.eql androidA.attendeeType
            attendee.attendeeStatus.should.eql androidA.attendeeStatus
        it "attendee2", ->
            attendee = obtained.attendees[1]
            androidA = androidEvent.attendees[1]
            attendee.attendeeEmail.should.eql androidA.attendeeEmail
            attendee.attendeeRelationship.should.eql androidA.attendeeRelationship
            attendee.attendeeType.should.eql androidA.attendeeType
            attendee.attendeeStatus.should.eql androidA.attendeeStatus

        it "reminders", ->
            obtained.reminders.length.should.eql androidEvent.reminders.length

        it "reminder1", ->
            obtained.reminders[0].minutes.should.eql androidEvent.reminders[0].minutes
            obtained.reminders[0].method.should.eql androidEvent.reminders[0].method

    describe 'RecurringAlldayEvent2Cozy', ->
        cozyEvent = jsonFixtures.event_recurringallday_cozy
        androidEvent = jsonFixtures.event_recurringallday_androidcreated

        obtained = ACH.event2Cozy androidEvent, calendarNames
        it "docType", ->
            obtained.docType.should.eql cozyEvent.docType
        it "start", ->
            obtained.start.should.eql cozyEvent.start
        it "end", ->
            obtained.end.should.eql cozyEvent.end
        it "place", ->
            obtained.place.should.eql cozyEvent.place
        it "description", ->
            obtained.description.should.eql cozyEvent.description
        it "details", ->
            obtained.details.should.eql cozyEvent.details
        it "rrule", ->
            # Both add useless and various precisions after ...
            obtained.rrule.slice(0, 11).should.eql cozyEvent.rrule.slice(0, 11)
        it "tags", ->
            obtained.tags.should.eql cozyEvent.tags
        it "timezone", ->
            expect(obtained.timezone).to.be.undefined
        # it "created", ->
        #     obtained.created.should.eql cozyEvent.created

        it "attendees", ->
            obtained.attendees.should.be.empty

        it "attendees", ->
            # Android create automatically an organsiser attendee.
            obtained.attendees.length.should.eql cozyEvent.attendees.length + 1

        it "attendee1", ->
            attendee = obtained.attendees[1]
            cozyA = cozyEvent.attendees[0]
            attendee.email.should.eql cozyA.email
            # Default status on android
            # is NEEDS-ACTION),
            # but cozy's is INVITATION-NOT-SENT
            attendee.status.should.eql 'NEEDS-ACTION'

        it "attendee2", ->
            attendee = obtained.attendees[2]
            cozyA = cozyEvent.attendees[1]
            attendee.email.should.eql cozyA.email
            # is NEEDS-ACTION),
            # but cozy's is INVITATION-NOT-SENT
            attendee.status.should.eql 'NEEDS-ACTION'

        it "alarms", ->
            obtained.alarms.length.should.eql cozyEvent.alarms.length

        # TODO: android is too smart and moves P7D to P6DT15H ie T9540M ...
        # it "alarms_1", ->
        #     alarm = obtained.alarms[0]
        #     cozyA = cozyEvent.alarms[0]
        #     # -PT24H' === '-P1D'
        #     moment.duration(alarm.trigg).asMinutes()
        #         .should.eql moment.duration(cozyA.trigg).asMinutes()
        #     alarm.action.should.eql cozyA.action
