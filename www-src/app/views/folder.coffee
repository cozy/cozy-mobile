CollectionView = require '../lib/view_collection'

module.exports = class FolderView extends CollectionView

    className: 'list'
    itemview: require './folder_line'

    menuEnabled: true

    events: ->
        'tap .cache-indicator': 'displaySlider'
        'hold .item': 'displaySlider'

    isParentOf: (otherFolderView) ->
        return true if @collection.path is null #root
        return false if @collection.isSearch()
        return false unless otherFolderView.collection.path
        return -1 isnt otherFolderView.collection.path.indexOf @collection.path

    initialize: ->
        super
        @listenTo @collection, 'sync', @onChange

    afterRender: ->
        @ionicView?.destroy()
        super
        @ionicView = new ionic.views.ListView
            el: @$el[0]
            _handleDrag: (e) =>
                # Avoid horizontal scroll, and slide to open menu.
                gesture = e.gesture
                if gesture.direction is 'up'
                    gesture.deltaX = 0
                    gesture.angle = -90
                    gesture.distance = -1 * gesture.deltaY
                    gesture.velocityX = 0
                else if gesture.direction is 'down'
                    gesture.deltaX = 0
                    gesture.angle = 90
                    gesture.distance = gesture.deltaY
                    gesture.velocityX = 0
                else
                    gesture.direction = 'down'
                    gesture.deltaX = 0
                    gesture.angle = 90
                    gesture.distance = 0
                    gesture.velocityX = 0
                    gesture.deltaX = 0

                @checkScroll()

                # unless menu is open or slide to right
                unless app.layout.isMenuOpen() or e.gesture.deltaX > 0
                    ionic.views.ListView::_handleDrag.apply @ionicView, arguments
                    # prevent menu from opening
                    e.preventDefault()
                    e.stopPropagation()

    onChange: =>
        app.layout.ionicScroll.resize()

        @$('#empty-message').remove()
        if _.size(@views) is 0
            message = if @collection.notloaded then 'loading'
            else if @collection.isSearch() then 'no results'
            else 'this folder is empty'

            $('<li class="item" id="empty-message">')
            .text(t(message))
            .appendTo @$el

        else unless @collection.allPagesLoaded
            $('<li class="item" id="empty-message">')
                .text(t('loading'))
                .appendTo @$el

    appendView: (view) =>
        super
        view.parent = this

    remove: =>
        super
        @collection.cancelFetchAdditional()

    displaySlider: (event) =>
        # simulate a drag effect on the line to display the hidden button
        op = new ionic.SlideDrag(el: @ionicView.el, canSwipe: -> true)
        op.start target: event.target

        if op._currentDrag.startOffsetX is 0
            # Button is actually hidden
            op.end gesture:
                deltaX: 0 - op._currentDrag.buttonsWidth
                direction: 'right'
            ionic.requestAnimationFrame => @ionicView._lastDragOp = op

        else
            # Hide button
            @ionicView.clearDragEffects()

        event.preventDefault()
        event.stopPropagation()


    checkScroll: =>
        triggerPoint = $('#viewsPlaceholder').height() * 2
        if app.layout.ionicScroll.getValues().top + triggerPoint > app.layout.ionicScroll.getScrollMax().top
            @loadMore()

    loadMore: (callback) ->
        if not @collection.notLoaded and
           not @isLoading and
           not @collection.allPagesLoaded
            @isLoading = true
            @collection.loadNextPage (err) =>

                @isLoading = false
                callback?()
