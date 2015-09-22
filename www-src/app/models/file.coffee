module.exports = class File extends Backbone.Model

    idAttribute: "_id"

    defaults: ->
        incache: 'loading'
        version: false

    initialize: ->
        @isDeviceFolder = @isFolder() and
        @wholePath() is app.replicator.config.get('deviceName')

    isFolder: ->
        @get('docType')?.toLowerCase() is 'folder'

    wholePath: ->
        name = @get('name')
        return if path = @get('path') then "#{path.slice(1)}/#{name}"
        else name