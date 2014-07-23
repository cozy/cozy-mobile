module.exports = class File extends Backbone.Model

    idAttribute: "_id"

    defaults: ->
        incache: 'loading'

    isFolder: ->
        @get('docType')?.toLowerCase() is 'folder'