BaseView = require './base_view'


log = require('../../lib/persistent_log')
    prefix: "Layout"
    date: true


module.exports = class Layout extends BaseView


    id: 'layout'
    template: require '../../templates/layout/layout'
    refs:
        contentContainer: '#contentContainer'


    initialize: ->
        @back = false
        document.addEventListener "backbutton", @onBackButtonClicked, false


    onBackButtonClicked: (event) =>
        log.info 'onBackButtonClicked'

        if @currentView.backExit
            if window.confirm t "confirm exit message"
                navigator.app.exitApp()
        else
            @back = true
            window.history.back()


    display: (@view, back = false) ->
        log.info 'display'
        animationEnd = 'webkitAnimationEnd mozAnimationEnd MSAnimationEnd' + \
                ' oanimationend animationend'

        animationExit =
            'animated ' + (@currentView?.animationExit or 'slideOutLeft')
        animationEntrance =
            'animated ' + (@view?.animationEntrance or 'slideInRight')

        if @back
            animationExit = animationExit.replace('Left', 'Right')
            animationEntrance = animationEntrance.replace('Right', 'Left')
            @back = false

        @oldView = @currentView
        @currentView = @view
        @contentContainer.append @view.render().$el


        if $("#contentContainer > div").length > 1
            oldPage = $("#contentContainer > div:first-child")
            newPage = $("#contentContainer > div:last-child")
            newPage
                .addClass(animationEntrance)
                .one animationEnd, ->
                    newPage.removeClass animationEntrance
            oldPage.addClass(animationExit)
            @oldView.destroyWithDelay()
        else
            newPage = $("#contentContainer > div:first-child")
            setTimeout ->
                newPage
                    .addClass(animationEntrance)
                    .one animationEnd, ->
                        newPage.removeClass animationEntrance
            , 100


    destroy: ->
        document.removeEventListener "backbutton", @onBackButtonClicked, false
        @undelegateEvents()
        @$el.removeData().unbind()
        @remove()
