should   = require('chai').should()
fileCacheHandler = require '../../../app/lib/file_cache_handler'
cozyFile =
    _id: 'ok'

module.exports = describe 'FileCacheHandler Test', ->

    it 'must have getFolderName function', ->
        folderName = fileCacheHandler.getFolderName cozyFile
        folderName.should.be.equal cozyFile._id
