CollectionView = require '../lib/view_collection'

module.exports = class FolderView extends CollectionView
    className: 'list'
    itemview: require './folder_line'