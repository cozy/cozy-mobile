BaseView = require './layout/base_view'
FileCacheHandler = require '../lib/file_cache_handler'
pathHelper = require '../lib/path'
mimetype = require '../lib/mimetype'

log = require('../lib/persistent_log')
    prefix: "MediaPlayerView"
    date: true

module.exports = class MediaPlayerView extends BaseView

    btnBackEnabled: true
    template: require '../templates/media_player'
    append: true
    refs:
        picture: '#mediaPicture'
        container: '.mediaContainer'
        modal: '#actions-modal'


    initialize: (@path, @mimetype) ->
        @fileCacheHandler = new FileCacheHandler()
        @fileName = pathHelper.getFileName @path
        @layout = app.router.layout
        @icon = mimetype.getIcon docType: 'file', mime: @mimetype
        $('body').removeClass 'bg-cozy-color'


    events: ->
        'click #exit': 'onClickExit'
        'click .actionDisplay': 'onClickOpen'
        'click .actionRemove': 'removeFile'
        'click .actions': 'displayActions'


    beforeRender: ->
        StatusBar.backgroundColorByHexString "#000"
        @layout.hideHeader()


    onClickOpen: (e) ->
        e.preventDefault()
        @modal.modal 'close'
        @fileCacheHandler.open @path


    onClickExit: (event) ->
        event.preventDefault() if event
        @layout.showHeader()
        window.history.back()
        @layout.alredyLoad = true
        @layout.views.pop()
        @destroy()


    removeFile: ->
        cozyFileId = pathHelper.getFileName pathHelper.getDirName @path
        cozyFile = _id: cozyFileId

        @fileCacheHandler.removeLocal cozyFile, =>
            @onClickExit()
            $("[data-key=#{cozyFileId}]").attr 'data-is-cached', 'false'
            $("[data-key=#{cozyFileId}] .is-cached").removeClass 'is-cached'


    getRenderData: ->
        mimetype:  @mimetype
        path: @path
        fileName: @fileName
        icon: @icon


    displayActions: (event) ->
        log.debug 'displayActions'

        event.preventDefault()
        event.stopPropagation()
        @modal.modal().modal 'open'


    destroy: ->
        StatusBar.backgroundColorByHexString "#33A6FF"
        $('body').addClass 'bg-cozy-color'
        super
