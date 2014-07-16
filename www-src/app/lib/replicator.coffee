request = require './request'
basic = require './basic'
fs = require './filesystem'
DBNAME = "cozy-files.db"
DBCONTACTS = "cozy-contacts.db"
DBOPTIONS = if window.isBrowserDebugging then {} else adapter: 'websql'

module.exports = class Replicator

    db: null
    server: null
    config: null

    destroyDB: (callback) ->
        @db.destroy (err) =>
            return callback err if err
            fs.rmrf @downloads, callback

    init: (callback) ->
        @initDownloadFolder (err) =>
            return callback err if err
            @db = new PouchDB DBNAME, DBOPTIONS
            @db.get 'localconfig', (err, config) =>
                if err
                    callback null, null
                else
                    @config = config
                    @remote = new PouchDB @config.fullRemoteURL
                    @contactsDB = new PouchDB DBCONTACTS, DBOPTIONS
                    @initDatabase (err) =>
                        return callback err if err
                        callback null, config

    initDownloadFolder: (callback) ->
        fs.initialize (err, filesystem) =>
            return callback err if err
            window.FileTransfer.fs = filesystem
            fs.getOrCreateSubFolder filesystem.root, 'cozy-downloads', (err, downloads) =>
                return callback err if err
                @downloads = downloads
                fs.getChildren downloads, (err, children) =>
                    return callback err if err
                    @cache = children
                    callback null

    createOrUpdateDesign: (db, design, callback) ->
        db.get design._id, (err, existing) =>
            if existing?.version is design.version
                return callback null
            else
                console.log "REDEFINING DESIGN #{design._id}"
                design._rev = existing._rev if existing
                db.put design, callback

    initDatabase: (callback) ->
        FilesAndFolderDesignDoc =
            _id: '_design/FilesAndFolder'
            version: 1
            views:
                'FilesAndFolder':
                    map: Object.toString.apply (doc) ->
                        if doc.docType?.toLowerCase() in ['file', 'folder']
                            emit doc.path

        LocalPathDesignDoc =
            _id: '_design/LocalPath'
            version: 1
            views:
                'LocalPath':
                    map: Object.toString.apply (doc) ->
                        emit doc.localPath if doc.localPath

        ContactsByLocalIdDesignDoc =
            _id: '_design/ContactsByLocalId'
            version: 1
            views:
                'ContactsByLocalId':
                    map: Object.toString.apply (doc) ->
                        if doc.docType?.toLowerCase() is 'contact' and doc.localId
                            emit doc.localId, [doc.localVersion, doc._rev]


        @createOrUpdateDesign @db, FilesAndFolderDesignDoc, (err) =>
            return callback err if err
            @createOrUpdateDesign @db, LocalPathDesignDoc, (err) =>
                return callback err if err
                @createOrUpdateDesign @contactsDB, ContactsByLocalIdDesignDoc, callback

    getDbFilesOfFolder: (folder, callback) ->
        path = folder.path + '/' + folder.name
        options =
            include_docs: true
            startkey: path
            endkey: path + '\uffff'

        @db.query 'FilesAndFolder', options, (err, results) ->
            return callback err if err
            docs = results.rows.map (row) -> row.doc
            files = docs.filter (doc) -> doc.docType?.toLowerCase() is 'file'
            callback null, files

    registerRemote: (config, callback) ->
        request.post
            uri: "https://#{config.cozyURL}/device/",
            auth:
                username: 'owner'
                password: config.password
            json:
                login: config.deviceName
                type: 'mobile'
        , (err, response, body) =>
            if err
                callback err
            else if response.statusCode is 401 and response.reason
                callback new Error('cozy need patch')
            else if response.statusCode is 401
                callback new Error('wrong password')
            else if response.statusCode is 400
                callback new Error('device name already exist')
            else
                config.password = body.password
                config.deviceId = body.id
                config.auth =
                    username: config.deviceName
                    password: config.password

                config.fullRemoteURL =
                    "https://#{config.deviceName}:#{config.password}" +
                    "@#{config.cozyURL}/cozy"

                @config = config
                @config._id = 'localconfig'
                @saveConfig callback

    saveConfig: (callback) ->
        @db.put @config, (err, result) =>
            return callback err if err
            return callback new Error(JSON.stringify(result)) unless result.ok
            @config._id = result.id
            @config._rev = result.rev
            callback null

    initialReplication: (progressback, callback) ->
        url = "#{@config.fullRemoteURL}/_changes?descending=true&limit=1"
        auth = @config.auth
        progressback 0
        request.get {url, auth, json: true}, (err, res, body) =>
            return callback err if err

            # we store last_seq before copying files & folder
            # to avoid losing changes occuring during replicatation
            last_seq = body.last_seq
            progressback 1/4
            @copyView 'file', (err) =>
                return callback err if err

                progressback 2/4
                @copyView 'folder', (err) =>
                    return callback err if err

                    progressback 3/4
                    @config.checkpointed = last_seq
                    @saveConfig callback

    copyView: (model, callback) ->
        url = "#{@config.fullRemoteURL}/_design/#{model}/_view/all/"
        auth = @config.auth
        request.get {url, auth, json:true}, (err, res, body) =>
            return callback err if err

            console.log "BUG? #{JSON.stringify(body)}"

            async.each body.rows, (row, cb) =>
                @db.put row.value, cb
            , callback


    binaryInCache: (binary_id) =>
        @cache.some (entry) -> entry.name is binary_id

    folderInCache: (folder, callback) =>
        @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err
            # a folder is in cache if all its children are in cache
            callback null, _.every files, (file) =>
                @binaryInCache file.binary.file.id

    getBinary: (model, callback, progressback) ->
        binary_id = model.binary.file.id

        fs.getOrCreateSubFolder @downloads, binary_id, (err, binfolder) =>
            return callback err if err
            return callback new Error('no model name :' + JSON.stringify(model)) unless model.name

            fs.getFile binfolder, model.name, (err, entry) =>
                return callback null, entry.toURL() if entry

                # getFile failed, let's download
                options =
                    from: encodeURI "https://#{@config.cozyURL}/cozy/#{binary_id}/file"
                    headers: Authorization: basic @config.deviceName, @config.password
                    to: binfolder.toURL() + '/' + model.name

                fs.download options, progressback, (err, entry) =>
                    if err
                        # failed to download
                        fs.delete binfolder, (delerr) ->
                            #@TODO handle delerr
                            callback err
                    else
                        @cache.push binfolder
                        callback null, entry.toURL()

    getBinaryFolder: (folder, callback, progressback) ->
        @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            totalSize = files.reduce ((sum, file) -> sum + file.size), 0

            fs.freeSpace (err, available) =>
                return callback err if err
                if totalSize > available * 1024 # available is in KB
                    alert 'There is not enough disk space, try download sub-folders.'
                    callback null
                else

                    progressHandlers = {}
                    reportProgress = ->
                        total = done = 0
                        for key, status of progressHandlers
                            done += status[0]
                            total += status[1]
                        progressback done, total


                    async.each files, (file, cb) =>
                        console.log "DOWNLOAD #{file.name}"
                        @getBinary file, cb, (done, total) ->
                            progressHandlers[file._id] = [done, total]
                            reportProgress()

                    , ->
                        return callback err if err
                        app.router.bustCache(folder.path + '/' + folder.name)
                        callback()


    removeLocal: (model, callback) ->
        binary_id = model.binary.file.id
        console.log "REMOVE LOCAL"
        console.log binary_id

        fs.getDirectory @downloads, binary_id, (err, binfolder) =>
            return callback err if err
            fs.rmrf binfolder, (err) =>
                # remove from @cache
                for entry, index in @cache when entry.name is binary_id
                    @cache.splice index, 1
                    break
                callback null

    removeLocalFolder: (folder, callback) ->
         @getDbFilesOfFolder folder, (err, files) =>
            return callback err if err

            async.eachSeries files, (file, cb) =>
                @removeLocal file, cb
            , (err) ->
                return callback err if err
                app.router.bustCache(folder.path + '/' + folder.name)
                callback()

    sync: (callback) ->
        @db.replicate.from @remote,
            filter: "#{@config.deviceId}/filter"
            since: @config.checkpointed
            complete: (err, result) =>
                console.log "REPLICATION COMPLETED"
                @config.checkpointed = result.last_seq
                @saveConfig =>
                    console.log "CONFIG SAVED"
                    @syncPictures =>
                        console.log "PICTURES SYNCED"
                        callback null

    syncContacts: (callback) ->
        async.parallel [
            ImagesBrowser.getContactsList
            (cb) => @contactsDB.query 'ContactsByLocalId', {}, cb
        ], (err, result) =>
            return callback err if err
            [phoneContacts, rows: dbContacts] = result

            console.log "BEGIN SYNC #{dbContacts.length} #{phoneContacts.length}"

            dbCache = {}
            dbContacts.forEach (row) ->
                dbCache[row.key] =
                    id: row.id
                    rev: row.value[1]
                    version: row.value[0]

            async.eachSeries phoneContacts, (contact, cb) =>

                contact.localId = contact.localId.toString()
                contact.docType = 'Contact'
                inDb = dbCache[contact.localId]

                console.log "CONTACT : #{contact.localId} #{contact.localVersion}"
                console.log "DB #{inDb}"

                # no changes
                if contact.localVersion is inDb?.version
                    console.log "NOTHING TO DO"
                    return cb null

                # the contact already exists, but has changed, we update it
                else if inDb?
                    console.log "UPDATING"
                    @contactsDB.put contact, inDb.id, inDb.rev, cb
                    return

                # this is a new contact
                else
                    console.log "CREATING"
                    @contactsDB.post contact, cb


            , callback

    replicateContacts: (callback) ->
        @contactsDB.query 'ContactsByLocalId', {}, (err, result) =>
            return callback err if err
            ids = result.rows.map (row) -> row.id
            @contactsDB.replicate.to @remote,
                doc_ids: ids,
                complete: callback


    syncPictures: (callback) ->
        ImagesBrowser.getImagesList (err, images) =>
            return callback err if err

            images = images[0..3] # for tests
            console.log "SYNC IMAGES : #{images.length}"
            async.eachSeries images, (path, cb) =>
                console.log "IMAGE : #{path}"
                @alreadyinDB path, (err, exist) =>
                    if err or exist
                        # dont break
                        console.log "ALREADY IN DB #{path} #{exist} #{err}"
                        return cb null

                    @uploadPicture path, (err) ->
                        console.log "ERROR #{err}"
                        cb null

            , callback

    alreadyinDB: (path, callback) ->
        @db.query 'LocalPath', key: path, (err, result) ->
            console.log "RESULT = #{result.rows.length}"
            callback err, result?.rows.length > 0

    uploadPicture: (path, callback) ->
        fs.getFileFromPath path, (err, file) =>
            return callback err if err

            fs.contentFromFile file, (err, content) =>
                return callback err if err

                @createBinary content, file.type, (err, bin) =>
                    return callback err if err

                    @createFile file, path, bin, callback


    createBinary: (blob, mime, callback) ->
        @remote.post docType: 'Binary', (err, doc) =>
            return callback err if err
            return callback new Error('cant create binary') unless doc.ok

            @remote.putAttachment doc.id, 'file', doc.rev, blob, mime, (err, doc) ->
                return callback err if err
                return callback new Error('cant attach') unless doc.ok
                callback null, doc

    createFile: (cordovaFile, localPath, binaryDoc, callback) ->

        dbFile =
            docType: 'File'
            name: cordovaFile.name
            path: '/' + @config.deviceName
            localPath: localPath
            type: @fileClassFromMime cordovaFile.type
            lastModification: new Date(cordovaFile.lastModified).toISOString()
            creationDate: new Date(cordovaFile.lastModified).toISOString()
            size: cordovaFile.size
            tags: ['uploaded-from-' + @config.deviceName]
            binary: file:
                id: binaryDoc.id
                rev: binaryDoc.rev

        @remote.post dbFile, (err, doc) =>
            return callback err if err
            return callback new Error('cant create file') unless doc.ok

            dbFile._id = doc.id
            dbFile._rev = doc.rev

            console.log "NOW #{JSON.stringify(dbFile)}"

            # put it immediately in local db
            @db.put dbFile, callback

    fileClassFromMime: (type) ->
        return switch type.split('/')[0]
            when 'image' then "image"
            when 'audio' then "music"
            when 'video' then "video"
            when 'text', 'application' then "document"
            else "file"
