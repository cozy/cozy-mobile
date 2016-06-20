async = require 'async'
DeviceStatus = require '../lib/device_status'
DesignDocuments = require './design_documents'
fs = require './filesystem'
toast = require '../lib/toast'
MediaUploader = require '../lib/media/media_uploader'


log = require('../lib/persistent_log')
    prefix: "replicator backup"
    date: true

# This files contains all replicator functions liked to backup
# use the ImagesBrowser cordova plugin to fetch images & contacts
# from phone.
# Set the inBackup attribute to true while a backup is in progress
# Set the backup_step attribute with value in
# [contacts_scan, pictures_sync, contacts_sync]
# For each step, hint of progress are in backup_step_done and backup_step_total

module.exports =

    # wrapper around _backup to maintain the state of inBackup
    backup: (options, callback = ->) ->

        return callback null if @get 'inBackup'

        try
            @set 'inBackup', true
            @set 'backup_step', 'pictures_scan'
            @set 'backup_step_done', null

            @mediaUploader = new MediaUploader()
            @listenTo @mediaUploader.pictureHandler, "change:queue", =>
                queue = @mediaUploader.pictureHandler.queue
                @set 'backup_step', 'pictures_upload'
                if queue > 0
                    unless @get 'backup_step_total'
                        @set 'backup_step_total', queue
                    done = @get('backup_step_total') - queue + 1
                    @set 'backup_step_done', done
            @mediaUploader.upload (err) =>
                @stopListening @mediaUploader.pictureHandler, "change:queue"
                log.error err if err

                @syncCache (err) =>
                    log.error err if err

                    @set 'backup_step', null
                    @set 'inBackup', false

                    @config.set 'lastBackup', Date.now()
                    log.debug "backup end."
        catch e
            log.error "Error in backup: ", e

        callback()
