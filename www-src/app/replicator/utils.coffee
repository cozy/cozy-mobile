module.exports.array2Hash = (array, key) ->
    obj = _.object _.pluck(array, key), array

    return obj

# module.exports.withNodeCB = (err, f, args..., callback) ->
#     return callback err if err

#     f.apply args
