module.exports =


    getDirName: (path) ->
        path.replace(/\\/g,'/').replace(/\/[^\/]*$/, '')


    getFileName: (path) ->
        path.replace(/^.*[\\\/]/, '')
