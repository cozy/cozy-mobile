BaseView = require '../lib/base_view'
Hammer = require 'hammer'
FileCacheHandler = require '../lib/file_cache_handler'

log = require('../lib/persistent_log')
    prefix: "MediaPlayerView"
    date: true

module.exports = class MediaPlayerView extends BaseView

    btnBackEnabled: true
    template: require '../templates/media_player'

    initialize: ->
        super
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
        @fileCacheHandler.open @options.path


    onClickExit: (e) ->
        e.preventDefault()
        window.history.back()


    getRenderData: ->
        path: @options.path


    onSwipe: (event) ->
        if event.originalEvent.gesture.direction is "right"
            window.history.back()
