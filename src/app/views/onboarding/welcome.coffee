BaseView = require '../layout/base_view'


module.exports = class Welcome extends BaseView


    className: 'page'
    template: require '../../templates/onboarding/welcome'
    animationEntrance: 'slideInDown'
    animationExit: 'fadeOutLeft'

    initialize: ->
        @backExit = true
        screen.lockOrientation 'portrait'
