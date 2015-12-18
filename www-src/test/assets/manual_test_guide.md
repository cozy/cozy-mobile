# Cozy Mobile manual test suite

Standard use case to test, and by version specific tests.

# Standard

# Upgrade scenario

- [ ] upgrade application
- [ ] start application
- [ ] view backup label
- [ ] navigate through folders
- [ ] download and open a file
- [ ] check contacts account
- [ ] check agenda account


# Install scenario

- [ ] uninstall the app from the device
- [ ] install the app
- [ ] choose to sync everithing, and wait for first sync

# Advanced scenarios

## File replication

- [ ] Add a file to the cozy
- [ ] Delete a file on the cozy
- [ ] Add a file in cache
- [ ] Rename this file in cache
- [ ] Delete this file in cache
- [ ] Add a folder
- [ ] Add a folder in cache
- [ ] Add a file in the folder
- [ ] Change the file in the folder
- [ ] Delete the folder
- [ ] Delete Photos directory, and let the app recreate it.

## Service

- [ ] close the app, and take a picture

## Contacts sync

Before each check, perform a sync in the app.

- [ ] Add a contact on cozy
- [ ] Add a contact on the device
- [ ] Change a contact on the cozy
- [ ] Change a contat on the device
- [ ] Delete a contact on the cozy
- [ ] Delete a contact on the device

## Calendar sync

- [ ] Add a event on cozy
- [ ] Add a event on the device
- [ ] Change a event on the cozy
- [ ] Change a contat on the device
- [ ] Delete a event on the cozy
- [ ] Delete a event on the device
- [ ] Add a event on a new calendar on the cozy
- [ ] Change the color of a calendar on the cozy
- [ ] Change the name of a calendar on the cozy
- [ ] Delete a calendar on the cozy


### Device --> Cozy

- [ ] Add a event
- [ ] Change time (start/end)
- [ ] Change day
- [ ] Change recurring (with and without end)
- [ ] Change reminders (add, delete, change type)
- [ ] Change invitation
- [ ] Change invitation, status
- [ ] Change allday
- [ ] Change description
- [ ] Change location
- [ ] Change one event in a reccuring
- [ ] Delete event

### Cozy --> Device
- [ ] Add a event
- [ ] Change time (start/end)
- [ ] Change day
- [ ] Change recurring (with and without end)
- [ ] Change reminders (add, delete, change type)
- [ ] Add event with more than 5 reminders (Android limitation)
- [ ] Change invitation
- [ ] Change invitation, status
- [ ] Change allday
- [ ] Change description
- [ ] Change location
- [ ] Change Calendar
- [ ] Delete event

### Conflicts

- [ ] Change two distincts events
- [ ] Change two fields of an event
- [ ] Change the same field of the same event.
