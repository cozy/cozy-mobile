fs     = require 'fs'
{exec} = require 'child_process'
async  = require './www-src/vendor/scripts/async'

plugins = [
    "https://github.com/aenario/cordova-external-file-open"
    "https://github.com/brodysoft/Cordova-SQLitePlugin"
    "https://git-wip-us.apache.org/repos/asf/cordova-plugin-file.git"
    "https://git-wip-us.apache.org/repos/asf/cordova-plugin-file-transfer.git"
    "https://github.com/aenario/cordova-images-browser"
]

platforms = ['ios', 'android']

installPlugins = (done) ->
    async.eachSeries plugins, (plugin, cb) ->
        console.log "installing plugin #{plugin} ..."
        command = 'cordova plugin add ' + plugin
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

installPlatforms = (done) ->
    async.eachSeries platforms, (platform, cb) ->
        console.log "attempt to add platform #{platform} ..."
        command = 'cordova platform add ' + platform
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

release = (done) ->

    password = fs.readFileSync 'keys/cozy-play-store.password', encoding: 'utf8'
    signing =  'jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 '
    signing += '-keystore keys/cozy-play-store.keystore -storepass '
    signing += password
    signing += ' platforms/android/ant-build/CozyFiles-release-unsigned.apk cozy-play-store'
    aligning = 'zipalign -v 4 platforms/android/ant-build/CozyFiles-release-unsigned.apk CozyFiles.apk'

    exec signing, (err, stdout, stderr) ->
        console.log stdout
        console.log stderr
        return done err if err
        exec aligning, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            return done err




task 'platforms', 'install cordova platforms', -> installPlatforms -> console.log "DONE"
task 'plugins', 'install cordova platforms', -> installPlugins -> console.log "DONE"
task 'release', 'create the released apk', -> release -> console.log "DONE"
