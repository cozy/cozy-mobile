should = require('chai').should()
helper = require '../../../helper/helper'
Transformer = helper.requireTestFile __filename

module.exports = describe 'Cozy To Android Calendar Transformer Test', ->


    transformer = new Transformer()

    it 'can transform cozy to android', ->
        cozyCalendar = helper.getCozyCalendar()
        account = helper.getAccount()
        androidCalendar = transformer.transform cozyCalendar, account
        should.not.exist androidCalendar._id

    it 'can transform cozy to android with old androidCalendar', ->
        cozyCalendar = helper.getCozyCalendar()
        account = helper.getAccount()
        androidCalendar = _id: "id"
        androidCalendar =
            transformer.transform cozyCalendar, account, androidCalendar
        androidCalendar._id.should.exist
