BaseView = require '../lib/base_view'
Hammer = require 'hammer'
FileCacheHandler = require '../lib/file_cache_handler'
pathHelper = require '../lib/path'

log = require('../lib/persistent_log')
    prefix: "MediaPlayerView"
    date: true

module.exports = class MediaPlayerView extends BaseView

    btnBackEnabled: true
    template: require '../templates/media_player'
    append: true
    refs:
        picture: '#mediaPicture'


    initialize: (@path) ->
        @fileCacheHandler = new FileCacheHandler()
        @fileName = pathHelper.getFileName @path
        @layout = app.router.layout


    events: ->
        'click #mediaPicture': 'toggleAction'
        'click #exit': 'onClickExit'
        'click #open': 'onClickOpen'
        'click #remove': 'removeFile'


    beforeRender: ->
        StatusBar.backgroundColorByHexString("#000");
        @layout.hideHeader()


    afterRender: ->
        setTimeout =>
            @toggleAction()
        , 1000

    toggleAction: ->
        @picture.toggleClass 'display-actions'



    onClickOpen: (e) ->
        e.preventDefault()
        @fileCacheHandler.open @path


    onClickExit: (event) ->
        event.preventDefault() if event
        @layout.showHeader()
        @destroy()


    removeFile: ->
        cozyFileId = pathHelper.getFileName(pathHelper.getDirName(@path))
        cozyFile = _id: cozyFileId

        @fileCacheHandler.removeLocal cozyFile, =>
            @onClickExit()
            $("[data-key=#{cozyFileId}] .is-cached").removeClass('is-cached')


    getRenderData: ->
        path: @path
        fileName: @fileName


    destroy: ->
        StatusBar.backgroundColorByHexString("#33A6FF");
        super
