BaseView = require './layout/base_view'
DesignDocuments = require '../replicator/design_documents'
FileCacheHandler = require '../lib/file_cache_handler'
ChangeFolderHandler = require '../replicator/change/change_folder_handler'
ChangeFileHandler = require '../replicator/change/change_file_handler'
HeaderView = require './layout/header'
pathHelper = require '../lib/path'
mimetype = require '../lib/mimetype'
semver = require 'semver'


log = require('../lib/persistent_log')
    prefix: "FileViewer"
    date: true


module.exports = class FileViewer extends BaseView


    btnBackEnabled: true
    template: require '../templates/file_viewer'
    backExit: false
    append: true
    refs:
        modal: '#actions-modal'
        openErrorModal: '#open-error-modal'


    events: ->
        'swipe .collection-item': 'onSwipe'
        'click .download': 'downloadFile'
        'click .goParent': 'goParent'
        'click .actions': 'displayActions'
        'click .actionDisplay': 'actionOpen'
        'click .actionDownload': 'downloadFile'
        'click .actionRemove': 'actionRemove'


    getRenderData: ->
        path: @options.path
        loading: @loading
        files: @files
        parentPath: @parentPath
        folderName: @folderName
        isViewerCompatible: @isViewerCompatible


    setIsViewerCompatible: ->
        if device.platform is "Android"
            # device.version is not a semantic version:
            #   - Froyo OS would return "2.2"
            #   - Eclair OS would return "2.1", "2.0.1", or "2.0"
            #   - Version can also return update level "2.1-update1"
            version = device.version.split('-')[0]
            version += '.0' unless semver.valid version
            if semver.valid(version) and semver.satisfies version, '<5.0.0'
                return @isViewerCompatible = false

        @isViewerCompatible = true


    initialize: ->
        super
        @fileCacheHandler = new FileCacheHandler()
        @router ?= app.router
        @loading = true
        @files = []
        @config ?= app.init.config
        @setIsViewerCompatible()

        if @options.path isnt '/'
            @parentPath = pathHelper.getDirName @options.path
            @parentPath = '/' unless @parentPath
            @folderName = pathHelper.getFileName @options.path
        else
            @append = false
            @parentPath = ''
            @backExit = true

        startLoading = =>
            if @config.get 'firstSyncFiles'
                @load @options.path
            else
                setTimeout ->
                    startLoading()
                , 1000

        startLoading()
        @loadjQueryFunction = false

        app.view = @

        @changeFolderHandler = new ChangeFolderHandler()
        @changeFileHandler = new ChangeFileHandler()
        cb = (object, path) =>
            if @parentPath is path
                @update()
        @listenTo @changeFolderHandler, "change:path", (object, path) =>
            if @parentPath is path
                @update()
        @listenTo @changeFileHandler, "change:path", (object, path) =>
            if @options.path is path
                @update()


    openFile: (url) ->
        @fileCacheHandler.open url, (err) =>
            if err isnt 'OK'
                log.warn err
                @openErrorModal.modal({ending_top: '20%'}).modal 'open'


    downloadFile: (event) ->
        log.debug 'downloadFile'
        $elem = $(event.currentTarget)
        if $elem.hasClass('actionDisplay') or $elem.hasClass 'actionDownload'
            menu = $ "[data-key=#{@modal.data 'key'}]"
            @modal.modal('close')
        else if $elem.hasClass 'collection-item'
            menu = $elem

            return if menu.data('doctype').toLowerCase() is 'folder'
            return if menu.data('cached') is true
        else
            menu = $elem.parents '.menuOpen'

        cozyFileId = menu.data 'key'
        if @fileCacheHandler.cache[cozyFileId]
            return if @isViewerCompatible and \
                    menu.data('is-compatible-viewer') and ! menu.data 'is-big'
            event.preventDefault()
            return @openFile menu.data 'fullpath'

        event.preventDefault()
        @files.forEach (file) =>
            if file._id is cozyFileId
                progressDesign = menu.find('.fileProgress')
                reportProgress = (id, done, total) ->
                    percentage = parseInt done * 100 / total
                    progressDesign.css('width', percentage + '%')
                progressBar = reportProgress.bind null, file._id
                menu.find('.progress').show()
                @fileCacheHandler.downloadBinary file, progressBar, =>
                    file.isCached = true
                    menu.find('.progress').hide()
                    progressDesign.css('width', '0%')
                    @render()
                    if @isViewerCompatible and \
                            menu.data('is-compatible-viewer') and \
                            ! menu.data 'is-big'
                        window.location = menu.attr('href')
                    else
                        @openFile menu.data 'fullpath'


    displayActions: (event) ->
        log.debug 'displayActions'

        event.preventDefault()
        event.stopPropagation()
        $elem = $(event.currentTarget).parents '.download'
        cached = $elem.data 'is-cached'
        if cached
            isBig = $elem.data 'is-big'
            @modal.toggleClass 'is-big', isBig
        else
            @modal.toggleClass 'is-big', false
        @modal.toggleClass 'cache', cached
        @modal.toggleClass 'no-cache', not cached
        @modal.data 'key', $elem.data 'key'

        # update trad key
        if $elem.data('is-cached') and $elem.data 'is-compatible-viewer'
            display = 'block'
        else
            display = 'none'
        $('.actionDisplay.in').css 'display', display

        @modal.find('.name').text $elem.data 'name'
        @modal.find('.file-icon')
            .attr('class', 'file-icon icon mdi mdi-' + $elem.data('type'))
        $(event.currentTarget).parents('.files').next('.modal').modal()
            .modal('open')


    actionOpen: (event) ->
        isIn = $(event.currentTarget).hasClass 'in'
        cozyFileId = @modal.data 'key'
        @modal.modal 'close'
        $elem = $('[data-key=' + cozyFileId + ']')
        if isIn and @isViewerCompatible and $elem.data 'is-compatible-viewer'
            window.location = $('[data-key=' + cozyFileId + ']').attr 'href'
        else
            @openFile $elem.data 'fullpath'


    actionRemove: (event) ->
        cozyFileId = @modal.data 'key'
        @files.forEach (file) =>
            if file._id is cozyFileId
                @fileCacheHandler.removeLocal file, =>
                    file.isCached = false
                    @render()


    onSwipe: (event) ->
        console.log 'swipe'
        direction = event?.originalEvent?.gesture?.direction
        if direction is 'right'
            @goParent()


    goParent: ->
        window.location = "#folder#{@parentPath}" if @options.path isnt '/'


    load: (filePath) ->
        if @header
            @header.update path: filePath, displaySearch: true
        else
            @header = new HeaderView path: filePath

        if filePath is '/'
            @backExit = true
            filePath = ''

        if filePath is t 'photos'
            params =
                startkey: [filePath, {}]
                endkey: [filePath]
                descending: true
            view = DesignDocuments.PICTURES
        else
            params =
                startkey: [filePath]
                endkey: [filePath, {}]
            view = DesignDocuments.FILES_AND_FOLDER

        @replicateDb ?= app.init.database.replicateDb
        @replicateDb.query view, params, (err, results) =>
            inPathIds = results.rows.map (row) -> return row.id

            params =
                keys: inPathIds
                include_docs: true

            @replicateDb.allDocs params, (err, items) =>
                @files = items.rows.map (row) =>
                    doc = row.doc
                    doc.icon = mimetype.getIcon doc
                    doc.isCached = @fileCacheHandler.isCached doc
                    if doc.icon is 'folder'
                        doc.link = "#folder#{doc.path}/#{doc.name}"
                    else
                        base = @fileCacheHandler.downloads.nativeURL
                        doc.fullPath = "#{base}#{doc._id}/#{doc.name}"
                        doc.link = "#media/#{doc.mime}//#{doc.fullPath}"
                        doc.isCompatibleViewer = mimetype.isCompatibleViewer doc

                    if doc.mime is 'application/pdf' and doc.size > 5000000 #5Mo
                        doc.isBig = true
                    return doc
                @loading = false
                @render()


    afterRender: ->
        if @options.path isnt '/'
            @back = 0
            setTimeout =>
                element = $('.snap-content').last()[0]
                @snapper = new Snap
                    element: element
                    disable: 'right'
                    maxPosition: element.offsetWidth
                    stopPropagation: false
                @snapper.on 'open', =>
                    if ++@back is 1
                        log.info @parentPath
                        @router.layout.goBack()
                        path = @router.layout.currentView.path
                        @router.navigate "folder#{path}", trigger: false
            , 1000


    update: ->
        @load @options.path
