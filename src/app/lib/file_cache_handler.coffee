log = require('./persistent_log')
    prefix: "FileCacheHandler"
    date: true


module.exports =


    getFolderName: (cozyFile) ->
        log.debug 'getFolderName'
        cozyFile._id
