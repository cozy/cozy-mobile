BaseView = require '../lib/base_view'
Hammer = require 'hammer'
FileCacheHandler = require '../lib/file_cache_handler'


module.exports = class MediaPlayerView extends BaseView


    btnBackEnabled: true
    template: require '../templates/media_player'


    initialize: (options) ->
        @path = options.path
        new Hammer @el
        @fileCacheHandler = new FileCacheHandler()


    events: ->
        'swipe': 'onSwipe'
        'tap': 'toggleMenu'
        'tap #exit': 'onClickExit'
        'tap #open': 'onClickOpen'


    toggleMenu: ->
        @$el.find('.actions').toggleClass 'hide'


    onClickOpen: (e) ->
        e.preventDefault()
        @fileCacheHandler.open @path


    onClickExit: (e) ->
        e.preventDefault()
        window.history.back()


    getRenderData: ->
        path: @path


    onSwipe: (event) ->
        if event.originalEvent.gesture.direction is "right"
            window.history.back()
