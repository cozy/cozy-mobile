async = require 'async'
DesignDocuments = require '../replicator/design_documents'
fs = require '../replicator/filesystem'
FileCacheHandler = require '../lib/file_cache_handler'
log = require('../lib/persistent_log')
    prefix: "migration 1.3.0"
    date: true


module.exports =


    migrate: (callback) ->
        @fileCacheHandler = new FileCacheHandler()
        @_findFolders (err, folders) =>
            return callback err if err
            return callback() if folders.length is 0

            @_getCozyFiles folders, (err, cozyFiles) =>
                return callback err if err
                return callback() if not cozyFiles or cozyFiles.length is 0

                async.eachSeries folders, (folder, cb) =>
                    id = folder.name.split('-')[0]
                    cozyFile = cozyFiles[id]
                    @_moveFile folder, cozyFile, (err) =>
                        if err
                            fs.rmrf folder, ->
                            log.warn 'Error move file in new folder.'
                            log.warn err, cozyFile, folder
                            return cb()
                        @fileCacheHandler.saveInCache cozyFile, true, (err) ->
                            if err
                                log.warn 'Error save in new cache.'
                                log.warn err, cozyFile, folder
                            fs.rmrf folder, (err) ->
                                if err
                                    log.warn 'Error remove old folder.'
                                    log.warn err, cozyFile, folder
                                cb()
                , callback


    _findFolders: (callback) ->
        fs.initialize (err, downloads) =>
            return callback err if err
            @downloads = downloads
            fs.getChildren @downloads, callback


    _getCozyFiles: (folders, callback) ->
        ids = []
        for folder in folders
            ids.push folder.name.split('-')[0]

        db = app.init.database.replicateDb
        options = include_docs: true
        db.query DesignDocuments.PATH_TO_BINARY, options, (err, results) ->
            return callback err if err
            return callback() if results.rows.length is 0

            cozyFiles = []
            for row in results.rows
                cozyFile = row.doc
                if cozyFile.binary?.file?.id in ids
                    cozyFiles[cozyFile.binary.file.id] = cozyFile
                    cozyFiles.push cozyFile

            callback null, cozyFiles


    _moveFile: (folder, cozyFile, callback) ->
        fileName = @fileCacheHandler.getFileName cozyFile
        folderName = @fileCacheHandler.getFolderName cozyFile

        fs.getOrCreateSubFolder @downloads, folderName, (err, newFolder) ->
            return callback err if err
            fs.getFile folder, fileName, (err, file) ->
                return callback err if err
                fs.moveTo file, newFolder, fileName, callback
