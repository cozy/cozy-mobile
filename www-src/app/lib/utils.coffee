
# Add setImmediate, because its one argument signature is cleaner to write
# with coffee script.
window.setImmediate = window.setImmediate or (callback) ->
    setTimeout callback, 1
