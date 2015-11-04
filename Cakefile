fs     = require 'fs'
{exec} = require 'child_process'
async  = require './www-src/vendor/scripts/async'

plugins = {
    "com.fgomiero.cordova.externafileutil": "https://github.com/aenario/cordova-external-file-open"
    #"com.brodysoft.sqlitePlugin": "https://github.com/brodysoft/Cordova-SQLitePlugin#r1.0.4"
    "org.apache.cordova.file": "https://git-wip-us.apache.org/repos/asf/cordova-plugin-file.git#r1.3.3"
    "org.apache.cordova.file-transfer": "https://git-wip-us.apache.org/repos/asf/cordova-plugin-file-transfer.git#r0.5.0"
    "io.cozy.cordova-images-browser": "https://github.com/aenario/cordova-images-browser"
    "io.cozy.jsbackgroundservice": "https://github.com/jacquarg/cordova-jsbackgroundservice#v1.0.1"
    "io.cozy.jsbgservice-newpicture": "https://github.com/jacquarg/cordova-jsbgservice-newpicture#v1.0.1"
    "io.cozy.contacts": "https://github.com/jacquarg/cordova-plugin-contacts#c1.0.3"
    "org.apache.cordova.battery-status": "org.apache.cordova.battery-status@0.2.12"
    "org.apache.cordova.network-information": "https://git-wip-us.apache.org/repos/asf/cordova-plugin-network-information.git#r0.2.15"
    "org.apache.cordova.globalization": "org.apache.cordova.globalization@0.3.4 "
    "de.appplant.cordova.plugin.local-notification": "de.appplant.cordova.plugin.local-notification@0.8.1"
    "org.apache.cordova.inappbrowser": "org.apache.cordova.inappbrowser@0.6.0",

}

platforms = ['ios', 'android']

installPlugins = (done) ->
    async.eachSeries Object.keys(plugins), (plugin, cb) ->
        plugin = plugins[plugin]
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

uninstallPlatforms = (done) ->
    async.eachSeries platforms, (platform, cb) ->
        console.log "attempt to remove platform #{platform} ..."
        command = 'cordova platform remove ' + platform
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

uninstallPlugins = (done) ->
    async.eachSeries Object.keys(plugins).reverse(), (plugin, cb) ->
        console.log "uninstalling plugin #{plugin} ..."
        command = 'cordova plugin rm ' + plugin
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

resetPlugins = (done) -> uninstallPlatforms -> installPlatforms done

updatePlugins = (done) -> uninstallPlugins -> installPlugins -> resetPlugins done



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
task 'plugins', 'install cordova plugins', -> installPlugins -> console.log "DONE"
task 'plugins:update', 'update cordova plugins', -> updatePlugins -> console.log "DONE"
task 'release', 'create the released apk', -> release -> console.log "DONE"
