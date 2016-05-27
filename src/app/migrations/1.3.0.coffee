async = require 'async'
DesignDocuments = require '../replicator/design_documents'
fs = require '../replicator/filesystem'
FileCacheHandler = require '../lib/file_cache_handler'


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
                        return cb err if err
                        @fileCacheHandler.saveInCache cozyFile, true, ->
                            fs.rmrf folder, cb
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
