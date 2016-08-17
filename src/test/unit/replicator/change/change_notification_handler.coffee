should   = require('chai').should()
ChangeNotificationHandler =
  require '../../../../app/replicator/change/change_notification_handler'


module.exports = describe 'ChangeNotificationHandler Test', ->


    notifHandler =
        removeCordovaNotification: -> false
        displayCordovaNotification: -> true

    changeNotificationHandler = new ChangeNotificationHandler notifHandler


    it 'can delete notification', ->
        changeNotificationHandler.dispatch({_deleted: true}).should.be.false


    it 'can add notification', ->
        changeNotificationHandler.dispatch({}).should.be.true
