CollectionView = require '../lib/view_collection'

module.exports = class FolderView extends CollectionView
    className: 'pane'
    itemview: require './folder_line'
    template: -> """
            <div class="list"></div>
        """
    collectionEl: '.list'
    isParentOf: (otherFolderView) ->
        return true if @collection.path is null #root
        return false if @collection.path is undefined #search
        return false unless otherFolderView.collection.path
        return -1 isnt otherFolderView.collection.path.indexOf @collection.path