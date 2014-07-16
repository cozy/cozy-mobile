BaseView = require '../lib/base_view'

module.exports = class FolderLineView extends BaseView

    tagName: 'a'
    template: require '../templates/folder_line'
    events:
        'click .item-content': 'onClick'
        'tap .item-options .download': 'addToCache'
        'tap .item-options .uncache': 'removeFromCache'

    className: 'item item-icon-left item-icon-right item-complex'

    initialize: =>
        @listenTo @model, 'change', @render

    afterRender: =>
        @$el[0].dataset.folderid = @model.get('_id')

    setCacheIcon: (klass) =>
        icon = @$('.cache-indicator')
        icon.removeClass('ion-warning ion-looping ion-ios7-cloud-download-outline')
        icon.removeClass('ion-ios7-download-outline').addClass klass
        @parent?.ionicView?.clearDragEffects()

    displayProgress: =>
        @hideProgress()
        @progresscontainer = $('<div class="item-progress"></div>')
            .append @progressbar = $('<div class="item-progress-bar"></div>')

        @progresscontainer.appendTo @$el

    hideProgress: =>
        @progresscontainer?.remove()

    updateProgress: (percent) =>
        @progressbar?.css 'width', (100 * percent) + '%'

    onClick: (event) =>
        return true if $(event.target).closest('.cache-indicator').length
        if @model.get('docType') is 'Folder'
            path = @model.get('path') + '/' + @model.get('name')
            app.router.navigate "#folder#{path}", trigger: true
        else
            @displayProgress()

            onprogress = (done, total) => @updateProgress done / total

            onload = (err, url) =>
                @hideProgress()
                return @onError err if err
                ExternalFileUtil.openWith url, '', undefined, @afterOpen, @onError


            app.replicator.getBinary @model.attributes, onload, onprogress

    addToCache: =>
        @setCacheIcon 'ion-looping'


        after = (err) =>
            @hideProgress()
            if err then alert err
            else @model.set incache: true
            @render()

        @displayProgress()
        onprogress = (done, total) => @updateProgress done / total

        if @model.get('docType') is 'Folder'
            app.replicator.getBinaryFolder @model.attributes, after, onprogress
        else
            app.replicator.getBinary @model.attributes, after, onprogress

    removeFromCache: =>
        @setCacheIcon 'ion-looping'
        after = (err) =>
            if err then alert err
            else @model.set incache: false
            @render()

        if @model.get('docType') is 'Folder'
            app.replicator.removeLocalFolder @model.attributes, after
        else
            app.replicator.removeLocal @model.attributes, after

    afterOpen: =>
        @model.set incache: true

    onError: (e) =>
        alert(e)
