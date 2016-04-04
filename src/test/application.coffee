should = chai.should()

application = require 'application'


module.exports = describe 'Application Controler', ->

    describe 'When application starts', ->
        Router     = require 'routes'
        LayoutView = require 'views/app_layout'

        before ->
            application.triggerMethod 'before:start'

        it 'should contains a router', ->
            application.should.have.property('router').to.be.an.instanceof \
                Router
        it 'should contains a layerView', ->
            application.should.have.property('layout').to.be.an.instanceof \
                LayoutView
