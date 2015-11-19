fs     = require 'fs'
{exec} = require 'child_process'
async  = require './www-src/vendor/scripts/async'

plugins = {
    "cordova-plugin-whitelist": "cordova-plugin-whitelist@1.0.0"

    "cordova-plugin-device": "cordova-plugin-device@1.0.1"
    "cordova-plugin-globalization": "cordova-plugin-globalization@1.0.1"
    "cordova-plugin-inappbrowser": "cordova-plugin-inappbrowser@1.0.1"
    "cordova-plugin-file": "cordova-plugin-file@3.0.0"
    "cordova-plugin-file-transfer": "cordova-plugin-file-transfer@1.3.0"
    "cordova-plugin-battery-status": "cordova-plugin-battery-status@1.1.0"
    "cordova-plugin-network-information": "cordova-plugin-network-information@1.0.1"

    "com.fgomiero.cordova.externafileutil": "https://github.com/aenario/cordova-external-file-open"
    "com.brodysoft.sqlitePlugin": "https://github.com/brodysoft/Cordova-SQLitePlugin#r1.0.4"
    "de.appplant.cordova.plugin.local-notification": "de.appplant.cordova.plugin.local-notification@0.8.2"

    "io.cozy.cordova-images-browser": "https://github.com/aenario/cordova-images-browser"
    "io.cozy.jsbackgroundservice": "https://github.com/jacquarg/cordova-jsbackgroundservice"
    "io.cozy.jsbgservice-newpicture": "https://github.com/jacquarg/cordova-jsbgservice-newpicture#v1.0.1"
    "io.cozy.contacts": "https://github.com/jacquarg/cordova-plugin-contacts#c1.0.3"
    "io.cozy.calendarsync": "https://github.com/jacquarg/cordova-plugin-calendarsync"
}

platforms = ['android']

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
