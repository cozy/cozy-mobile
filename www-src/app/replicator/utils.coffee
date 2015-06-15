module.exports.array2Hash = (array, key) ->
    obj = _.object _.pluck(array, key), array

    console.log obj
    return obj
