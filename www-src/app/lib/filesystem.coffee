
splitCallback = (callback) ->
    return [
        onSuccess = (x) -> callback null, x
        onError = (err) -> callback err
    ]



module.exports.initialize = (callback) ->
    onSuccess = (fs) -> callback null, fs
    onError = (err) -> callback err
    __chromeSafe() if window.isBrowserDebugging # flag for developpement in browser
    window.requestFileSystem LocalFileSystem.PERSISTENT, 0, onSuccess, onError

module.exports.delete = (entry, callback) ->
    onSuccess = -> callback null
    onError = (err) -> callback err
    entry.remove onSuccess, onError

module.exports.getFile = (parent, name, callback) ->
    onSuccess = (entry) -> callback null, entry
    onError = (err) -> callback err
    parent.getFile name, null, onSuccess, onError

module.exports.getDirectory = (parent, name, callback) ->
    onSuccess = (entry) -> callback null, entry
    onError = (err) -> callback err
    parent.getDirectory name, {}, onSuccess, onError

module.exports.getOrCreateSubFolder = (parent, name, callback) ->
    onSuccess = (entry) -> callback null, entry
    onError = (err) -> callback err
    parent.getDirectory name, {create: true}, onSuccess, onError

module.exports.getChildren = (directory, callback) ->
    # assume we are using cordova-file-plugin and call reader only once
    reader = directory.createReader()
    onSuccess = (entries) -> callback null, entries
    onError = (err) -> callback err
    reader.readEntries onSuccess, onError

module.exports.rmrf = (directory, callback) ->
    onError = (err) -> callback err
    onSuccess = -> callback null
    directory.removeRecursively onSuccess, onError

module.exports.freeSpace = (callback) ->
    onError = (err) -> callback err
    onSuccess = -> callback null
    cordova.exec onSuccess, onError, 'File', 'getFreeDiskSpace', []


module.exports.entryFromPath = (path, callback) ->
    onSuccess = (entry) -> callback null, entry
    onError = (err) -> callback err
    resolveLocalFileSystemURL 'file://' + path, onSuccess, onError

module.exports.fileFromEntry = (entry, callback) ->
    onSuccess = (file) -> callback null, file
    onError = (err) -> callback err
    entry.file onSuccess, onError

module.exports.contentFromFile = (file, callback) ->
    [onSuccess, onError] = splitCallback callback
    reader = new FileReader()
    reader.onerror = onError
    reader.onload = -> onSuccess reader.result
    reader.readAsArrayBuffer file

module.exports.getFileFromPath = (path, callback) ->
    module.exports.entryFromPath path, (err, entry) ->
        return callback err if err
        module.exports.fileFromEntry entry, callback

module.exports.metadataFromEntry = (entry, callback) ->
    onSuccess = (file) -> callback null, file
    onError = (err) -> callback err
    entry.getMetadata onSuccess, onError


module.exports.download = (options, progressback, callback) ->
    headers = options.headers
    url = options.from
    local = options.to

    errors = [
        'An error happened (UNKNOWN)',
        'An error happened (NOT FOUND)',
        'An error happened (INVALID URL)',
        'This file isnt available offline',
        'ABORTED'
    ]

    onSuccess = (entry) -> callback null, entry
    onError = (err) -> callback new Error errors[err.code]

    ft = new FileTransfer()
    ft.onprogress = (e) ->
        if e.lengthComputable then progressback e.loaded, e.total
        else progressback 3, 10 #@TODO, better aproximation

    ft.download url, local, onSuccess, onError, true, {headers}


# various patches to debug in chrome
__chromeSafe = ->
    window.LocalFileSystem = PERSISTENT: window.PERSISTENT
    window.requestFileSystem = (type, size, onSuccess, onError) ->
        size = 5*1024*1024
        navigator.webkitPersistentStorage.requestQuota size, (granted) ->
            window.webkitRequestFileSystem type, granted, onSuccess, onError
        , onError


    window.FileTransfer = class FileTransfer
        download: (url, local, onSuccess, onError, _, options) ->
            xhr = new XMLHttpRequest();
            xhr.open 'GET', url, true
            xhr.overrideMimeType 'text/plain; charset=x-user-defined'
            xhr.responseType = "arraybuffer";
            xhr.setRequestHeader key, value for key, value of options.headers
            xhr.onreadystatechange = ->
                return unless xhr.readyState == 4
                FileTransfer.fs.root.getFile local, {create: true}, (entry) ->
                    entry.createWriter (writer) ->
                        writer.onwrite = -> onSuccess entry
                        writer.onerror = (err) -> onError err
                        bb = new BlobBuilder();
                        bb.append(xhr.response);
                        writer.write(bb.getBlob(mimetype));

                    , (err) -> onError err
                , (err) -> onError err
            xhr.send(null)