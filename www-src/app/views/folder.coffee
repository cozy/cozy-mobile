CollectionView = require '../lib/view_collection'

module.exports = class FolderView extends CollectionView


    className: 'list'
    itemview: require './folder_line'
    events: ->
        'click .cache-indicator': 'displaySlider'

    isParentOf: (otherFolderView) ->
        return true if @collection.path is null #root
        return false if @collection.path is undefined #search
        return false unless otherFolderView.collection.path
        return -1 isnt otherFolderView.collection.path.indexOf @collection.path

    afterRender: ->
        super
        @ionicView = new ionic.views.ListView
            el: @$el[0]
            _handleDrag: (e) ->
                ionic.views.ListView::_handleDrag.apply this, arguments
                # prevent menu from opening
                e.stopPropagation()

        @collection.fetchAdditional()

    appendView: (view) =>
        super
        view.parent = this

    displaySlider: (event) =>
        @ionicView.clearDragEffects()
        op = new ionic.SlideDrag(el: @ionicView.el, canSwipe: -> true)
        op.start target: event.target
        dX = if op._currentDrag.startOffsetX is 0 then 0 - op._currentDrag.buttonsWidth
        else op._currentDrag.buttonsWidth
        op.end gesture:
            deltaX: dX
            direction: 'right'
        ionic.requestAnimationFrame => @ionicView._lastDragOp = op
        event.preventDefault()
        event.stopPropagation()