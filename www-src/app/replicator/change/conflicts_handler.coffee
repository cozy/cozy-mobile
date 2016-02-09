async = require 'async'

log = require('../../lib/persistent_log')
    prefix: "ConflictsHandler"
    date: true

module.exports = class ConflictsHandler

    constructor: (@db)->

    handleConflicts: (doc, callback) ->
        log.info "handleConflicts"

        # Get the doc with conflicts (and revs) infos from Pouch
        @db.get doc._id, { conflicts: true, revs: true }, (err, local) =>
            return callback err if err

            if local._conflicts?
                @_handleConflicts doc, local, callback
            else
                callback null, doc


    ###*
     * Resolve the conflicts, always keeping the given cozy's doc.
     * @param doc just received from cozy
     * @param local the version in the pouch, with conflicts and revs infos
     * @param callback with return the keeped doc (the cozy's one)
    ###
    _handleConflicts: (doc, local, callback) ->
        log.info "fixes conflicts for #{doc._id}"

        # Collect all conflicts to remove, excluding version from cozy
        revsToDelete = local._conflicts.filter (rev) -> rev isnt doc._rev

        # If pouch had chosen to keep its version, the cozy's rev is in
        # conflicts. We have to remove the other one
        if revsToDelete.length isnt local._conflicts.length
            revNum = parseInt doc._rev.split('-')[0]
            # That's how revisions are classed in conflicts array
            idx = local._revisions.start - revNum
            revsToDelete.push "#{revNum}-#{local._revisions.ids[idx]}"

        # Apply clean up.
        async.each revsToDelete, (rev, cb) =>
            log.info "remove revision #{rev}"
            @db.remove doc._id, rev, cb
        , (err) ->
            callback err, doc
