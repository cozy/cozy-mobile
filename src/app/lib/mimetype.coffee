log = require('./persistent_log')
    prefix: "mimetype"
    date: true

module.exports =


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
        'text/plain'                    : 'file-document'
        'text/x-markdown'               : 'file-document'
        'text/richtext'                 : 'file-document'
        'application/x-rtf'             : 'file-document'
        'application/rtf'               : 'file-document'
        'application/msword'            : 'file-document'
        'application/x-iwork-pages-sffpages' : 'file-document'

        'application/epub+zip'          : 'book-open-variant'
        'application/x-mobipocket-ebook': 'book-open-variant'

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
        'video/webm'                    : 'file-video'
        'video/x-m4v'                   : 'file-video'

        'application/x-binary'          : 'archive'
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

        'application/vnd.android.package-archive' : 'android'
