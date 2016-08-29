BaseView = require '../lib/base_view'

log = require('../lib/persistent_log')
  prefix: "MediaPlayerView"
  date: true

module.exports = class MediaPlayerView extends BaseView

    btnBackEnabled: true
    template: require '../templates/media_player'


    getRenderData: ->
        path: @options.path
