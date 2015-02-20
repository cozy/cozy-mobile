BaseView = require '../lib/base_view'

module.exports = class FolderLineView extends BaseView

    tagName: 'a'
    template: require '../templates/folder_line'
    events:
        'tap .item-content': 'onClick'
        'tap .item-options .download': 'addToCache'
        'tap .item-options .uncache': 'removeFromCache'

    className: 'item item-icon-left item-icon-right item-complex'

    initialize: =>
        @listenTo @model, 'change', @render

    getRenderData: ->
        _.extend super, isFolder: @model.isFolder()

    afterRender: =>
        @$el[0].dataset.folderid = @model.get('_id')
        if @model.isDeviceFolder
            @$('.ion-folder').css color: '#34a6ff'

    setCacheIcon: (klass) =>
        icon = @$('.cache-indicator')
        icon.removeClass('ion-warning ion-looping ion-ios7-cloud-download-outline')
        icon.removeClass('ion-ios7-download-outline')
        icon.append klass
        @parent?.ionicView?.clearDragEffects()

    displayProgress: =>
        @downloading = true
        @setCacheIcon '<img src="img/spinner.svg"></img>'
        @progresscontainer = $('<div class="item-progress"></div>')
            .append @progressbar = $('<div class="item-progress-bar"></div>')

        @progresscontainer.appendTo @$el

    hideProgress: (err, incache) =>
        @downloading = false
        if err then alert err

        incache = app.replicator.fileInFileSystem @model.attributes
        version = app.replicator.fileVersion @model.attributes

        if incache? and incache isnt @model.get 'incache'
            @model.set {incache}

        if version? and version isnt @model.get 'version'
            @model.set {version}

        @progresscontainer?.remove()
        @render()

    updateProgress: (done, total) =>
        @progressbar?.css 'width', (100 * done / total) + '%'

    getOnDownloadedCallback: (callback) ->
        callback = callback or ->
        return (err, url) =>
            @hideProgress()
            return alert t(err.message) if err
            @model.set incache: true
            @model.set version: app.replicator.fileVersion @model.attributes
            callback(err, url)

    onClick: (event) =>
        # ignore .cache-indicator click
        # they are handled by folder.coffee#displaySlider
        return true if $(event.target).closest('.cache-indicator').length
        return true if @downloading

        if @model.isFolder()
            path = @model.get('path') + '/' + @model.get('name')
            app.router.navigate "#folder#{path}", trigger: true
            return true

        # else, the model is a file, we get its binary and open it
        @displayProgress()
        app.replicator.getBinary @model.attributes, @updateProgress, \
          @getOnDownloadedCallback (err, url) =>
            # let android open the file
            app.backFromOpen = true
            ExternalFileUtil.openWith url, '', undefined,
                (success) -> , # do nothing
                (err) ->
                    if 0 is err?.indexOf 'No Activity found'
                        err = t 'no activity found'
                    alert err
                    console.log err

    addToCache: =>
        return true if @downloading

        @displayProgress()
        if @model.isFolder()
            app.replicator.getBinaryFolder @model.attributes, @updateProgress,\
                @getOnDownloadedCallback()
        else
            app.replicator.getBinary @model.attributes, @updateProgress, \
                @getOnDownloadedCallback()

    removeFromCache: =>
        return true if @downloading

        @displayProgress()
        onremoved = (err) =>
            @hideProgress()
            return alert err if err
            @model.set incache: false

        if @model.isFolder()
            app.replicator.removeLocalFolder @model.attributes, onremoved
        else
            app.replicator.removeLocal @model.attributes, onremoved
