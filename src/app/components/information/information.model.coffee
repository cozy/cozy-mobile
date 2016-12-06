PictureHandler = require '../../lib/media/picture_handler'
FirstReplication = require '../../lib/first_replication'


module.exports = class Information extends Backbone.Model


    initialize: ->
        @firstReplication = new FirstReplication()
        @listenTo @firstReplication, "change:queue", (object, @task) =>
            if @task
                @set text: t 'config_loading_' + @task, progress: 0
            else
                @set text: '', progress: 0
        @listenTo @firstReplication, "change:total", (object, total) =>
            if @task is 'files'
                @total = total
            else
                @total = total * 2
        @listenTo @firstReplication, "change:progress", (object, progress) =>
            @set progress: progress * 100 / @total

        @pictureHandler = new PictureHandler()
        @listenTo @pictureHandler, "change:total", (object, @total) =>
            @set text: t 'information_backup_picture'
        @listenTo @pictureHandler, "change:progress", (object, progress) =>
            if progress is @total
                @set text: '', progress: 0
            else
                @set progress: progress * 100 / @total


    defaults: ->
        display: true
        text: ''
        progress: 0
