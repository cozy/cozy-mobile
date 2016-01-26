
# Add setImmediate, because its one argument signature is cleaner to write
# with coffee script.
window.setImmediate = window.setImmediate or (callback) ->
    setTimeout callback, 1

# Simple continue on error helper, to use with async for example.
# How to use :
# Initialize a 'continueOnError' helper on top of the module, giving
# the specific logger. Then wrap the callback with it in the code :
# Typycally continueOnError(cb)(err)
module.exports.continueOnError = (log) ->
    (callback) ->
        (err) ->
            if err
                log.error 'Continue on error:', err
                callback null # continue
            else
                callback.apply @, arguments
