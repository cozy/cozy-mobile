BaseView = require '../lib/base_view'
Hammer = require 'hammer'

log = require('../lib/persistent_log')
    prefix: "MediaPlayerView"
    date: true

module.exports = class MediaPlayerView extends BaseView

    btnBackEnabled: true
    template: require '../templates/media_player'

    initialize: ->
        super
        new Hammer @el


    events: ->
        'swipe': 'onSwipe'


    getRenderData: ->
        path: @options.path


    onSwipe: (event) ->
        if event.originalEvent.gesture.direction is "right"
            window.history.back()
