BaseView = require '../lib/base_view'
Hammer = require 'hammer'
DesignDocuments = require '../replicator/design_documents'
FileCacheHandler = require '../lib/file_cache_handler'
HeaderView = require './layout/header'


log = require('../lib/persistent_log')
  prefix: "FileViewer"
  date: true


module.exports = class FileViewer extends BaseView


    btnBackEnabled: true
    template: require '../templates/file_viewer'
    backExit: false
    append: true


    events: ->
        'swipe .collection-item': 'onSwipe'
        'click .menu': 'toggleMenu'
        'click .remove': 'removeFile'
        'click .download': 'downloadFile'
        'click .toggleSearch': 'toggleSearch'
        'click .goParent': 'goParent'


    getRenderData: ->
        path: @options.path
        loading: @loading
        files: @files
        parentPath: @parentPath
        folderName: @folderName
        breadcrumb: @breadcrumb


    initialize: ->
        super
        @fileCacheHandler = new FileCacheHandler()
        @router ?= app.router
        @loading = true
        @files = []
        @config ?= app.init.config

        @breadcrumb = @getBreadcrumb @options.path

        if @options.path isnt '/'
            @parentPath = @options.path.replace(/\\/g,'/').replace(/\/[^\/]*$/, '')
            @parentPath = '/' unless @parentPath
            @folderName = @options.path.replace(/^.*[\\\/]/, '')
        else
            @append = false
            @parentPath = ''
            @backExit = true

        startLoading = =>
            if @config.get 'firstSyncFiles'
                @load @options.path
            else
                setTimeout =>
                    startLoading()
                , 1000

        startLoading()
        @loadjQueryFunction = false

        app.view = @


    getBreadcrumb: (path) ->
        split = path.split '/'
        breadcrumb = []
        link = ''

        for name in split
            link += "/#{name}" if name
            breadcrumb.push
                link: link
                name: name

        breadcrumb


    downloadFile: (event) ->
        if $(event.currentTarget).hasClass 'collection-item'
            menu = $(event.currentTarget)

            return if menu.data('doctype').toLowerCase() is 'folder'
            return if menu.data('cached') is true
        else
            menu = $(event.currentTarget).parents '.menuOpen'

        cozyFileId = menu.data 'key'
        if @fileCacheHandler.cache[cozyFileId]
            return if menu.data('type') is 'file-image'
            event.preventDefault()
            return @fileCacheHandler.open menu.data 'fullpath'

        event.preventDefault()
        @files.forEach (file) =>
            if file._id is cozyFileId
                progressDesign = menu.find('.fileProgress')
                reportProgress = (id, done, total) =>
                    percentage = parseInt done * 100 / total
                    progressDesign.css('width', percentage + '%')
                pregressBar = reportProgress.bind null, file._id
                menu.find('.progress').show()
                @fileCacheHandler.downloadBinary file, pregressBar, =>
                    file.isCached = true
                    menu.find('.progress').hide()
                    progressDesign.css('width', '0%')
                    @render()
                    if menu.data('type') is 'file-image'
                        @router.navigate menu.attr('href'), trigger: true
                    else
                        @fileCacheHandler.open menu.data 'fullpath'


    removeFile: (event) ->
        event.preventDefault()

        cozyFileId = $(event.currentTarget).parents('.menuOpen').data 'key'
        @files.forEach (file) =>
            if file._id is cozyFileId
                @fileCacheHandler.removeLocal file, =>
                    file.isCached = false
                    @render()


    toggleMenu: (event) ->
        event.preventDefault()

        menu = $(event.currentTarget)
        collection = menu.parent()
        isOpen = collection.hasClass 'menuOpen'

        # close all menu
        $('.menuOpen').each (index) ->
            $(this).removeClass 'menuOpen'
            $(this).find('.menu').closeFAB()

        unless isOpen
            collection.toggleClass 'menuOpen'
            menu.openFAB()



    onSwipe: (event) ->
        console.log 'swipe'
        direction = event?.originalEvent?.gesture?.direction
        if direction is 'right'
            @goParent()


    goParent: ->
        window.location = "#folder#{@parentPath}" if @options.path isnt '/'


    load: (filePath) ->
        console.log "filePath: #{filePath}"

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

        app.init.replicator.db.query view, params, (err, results) =>
            inPathIds = results.rows.map (row) -> return row.id

            params =
                keys: inPathIds
                include_docs: true

            app.init.replicator.db.allDocs params, (err, items) =>
                @files = items.rows.map (row) =>
                    doc = row.doc
                    doc.icon = @getIcon doc
                    doc.isCached = @fileCacheHandler.isCached doc
                    if doc.icon is 'folder'
                        doc.link = "#folder#{doc.path}/#{doc.name}"
                    else
                        base = @fileCacheHandler.downloads.nativeURL
                        doc.fullPath = "#{base}#{doc._id}/#{doc.name}"
                        doc.link = "#media/#{doc.fullPath}"
                    return row.doc
                @loading = false
                @render()


    afterRender: ->
        breadcrumb = document.getElementById "breadcrumb"
        breadcrumb.scrollLeft = breadcrumb.scrollWidth if breadcrumb
        if @options.path isnt '/'
            @back = 0
            setTimeout =>
                element = $('.files').last()[0]
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


    getIcon: (cozyFile) ->
        if cozyFile.docType.toLowerCase() is 'folder'
            return 'folder'
        else if @mimeClasses[cozyFile.mime]
            return @mimeClasses[cozyFile.mime]
        else
            log.info 'mimetype not supported: ', cozyFile.mime
            return 'file'



    mimeClasses:
        'application/octet-stream'      : 'file-document'
        'application/x-binary'          : 'archive'
        'text/plain'                    : 'file-document'
        'text/richtext'                 : 'file-document'
        'application/x-rtf'             : 'file-document'
        'application/rtf'               : 'file-document'
        'application/msword'            : 'file-document'
        'application/x-iwork-pages-sffpages' : 'file-document'
        'application/mspowerpoint'      : 'presentation-play'
        'application/vnd.ms-powerpoint' : 'presentation-play'
        'application/x-mspowerpoint'    : 'presentation-play'
        'application/x-iwork-keynote-sffkey' : 'presentation-play'
        'application/excel'             : 'file-chart'
        'application/x-excel'           : 'file-chart'
        'aaplication/vnd.ms-excel'      : 'file-chart'
        'application/x-msexcel'         : 'file-chart'
        'application/x-iwork-numbers-sffnumbers' : 'file-chart'
        'application/pdf'               : 'file-pdf'
        'text/html'                     : 'file-xml'
        'text/asp'                      : 'file-xml'
        'text/css'                      : 'file-xml'
        'application/x-javascript'      : 'file-xml'
        'application/x-lisp'            : 'file-xml'
        'application/xml'               : 'file-xml'
        'text/xml'                      : 'file-xml'
        'application/x-sh'              : 'file-xml'
        'text/x-script.python'          : 'file-xml'
        'application/x-bytecode.python' : 'file-xml'
        'text/x-java-source'            : 'file-xml'
        'application/postscript'        : 'file-image'
        'image/gif'                     : 'file-image'
        'image/jpg'                     : 'file-image'
        'image/jpeg'                    : 'file-image'
        'image/pjpeg'                   : 'file-image'
        'image/x-pict'                  : 'file-image'
        'image/pict'                    : 'file-image'
        'image/png'                     : 'file-image'
        'image/x-pcx'                   : 'file-image'
        'image/x-portable-pixmap'       : 'file-image'
        'image/x-tiff'                  : 'file-image'
        'image/tiff'                    : 'file-image'
        'audio/aiff'                    : 'file-music'
        'audio/x-aiff'                  : 'file-music'
        'audio/midi'                    : 'file-music'
        'audio/x-midi'                  : 'file-music'
        'audio/x-mid'                   : 'file-music'
        'audio/mpeg'                    : 'file-music'
        'audio/x-mpeg'                  : 'file-music'
        'audio/mpeg3'                   : 'file-music'
        'audio/x-mpeg3'                 : 'file-music'
        'audio/wav'                     : 'file-music'
        'audio/x-wav'                   : 'file-music'
        'audio/mp4'                     : 'file-music'
        'audio/ogg'                     : 'file-music'
        'audio/flac'                    : 'file-music'
        'audio/x-flac'                  : 'file-music'
        'video/avi'                     : 'file-video'
        'video/mpeg'                    : 'file-video'
        'video/mp4'                     : 'file-video'
        'application/zip'               : 'archive'
        'multipart/x-zip'               : 'archive'
        'multipart/x-zip'               : 'archive'
        'application/x-bzip'            : 'archive'
        'application/x-bzip2'           : 'archive'
        'application/x-gzip'            : 'archive'
        'application/x-compress'        : 'archive'
        'application/x-compressed'      : 'archive'
        'application/x-zip-compressed'  : 'archive'
        'application/x-apple-diskimage' : 'archive'
        'multipart/x-gzip'              : 'archive'
