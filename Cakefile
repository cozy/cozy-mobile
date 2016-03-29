fs     = require 'fs'
{exec} = require 'child_process'
packageJson = require './src/package.json'

installDependencies = (done) ->
    console.log "install dependencies"
    command = "cd src && npm install && cd .."
    exec command, (err, stdout, stderr) ->
        console.log stdout
        console.log stderr
        done()

installPlatforms = (done) ->
    console.log "install cordova platforms"
    async  = require './src/modules/async'
    async.eachSeries packageJson.cordovaPlatforms, (platform, cb) ->
        console.log "attempt to add platform #{platform} ..."
        command = './src/node_modules/.bin/cordova platform add ' + platform
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

uninstallPlatforms = (done) ->
    console.log "uninstall cordova platforms"
    async  = require './src/modules/async'
    async.eachSeries packageJson.cordovaPlatforms, (platform, cb) ->
        console.log "attempt to remove platform #{platform} ..."
        command = './src/node_modules/.bin/cordova platform remove ' + platform
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

installPlugins = (done) ->
    console.log "install cordova plugins"
    async  = require './src/modules/async'
    async.eachSeries Object.keys(packageJson.cordovaPlugins), (plugin, cb) ->
        pluginName = packageJson.cordovaPlugins[plugin]
        console.log "installing plugin #{plugin} ..."
        command = './src/node_modules/.bin/cordova plugin add ' + pluginName
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

uninstallPlugins = (done) ->
    console.log "uninstall cordova plugins"
    async  = require './src/modules/async'
    async.eachSeries Object.keys(packageJson.cordovaPlugins).reverse(), (plugin, cb) ->
        console.log "uninstalling plugin #{plugin} ..."
        command = './src/node_modules/.bin/cordova plugin rm ' + plugin
        exec command, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            cb()
    , done

resetPlugins = (done) ->
    console.log "reset cordova plugins"
    uninstallPlatforms -> installPlatforms done

updatePlugins = (done) ->
    console.log "update cordova plugins"
    uninstallPlugins -> installPlugins -> resetPlugins done



release = (done) ->
    password = fs.readFileSync 'keys/cozy-play-store.password', encoding: 'utf8'
    signing =  'jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 '
    signing += '-keystore keys/cozy-play-store.keystore -storepass '
    signing += password
    signing += ' platforms/android/build/outputs/apk/android-release-unsigned.apk cozy-play-store'
    aligning = 'zipalign -v 4 platforms/android/build/outputs/apk/android-release-unsigned.apk CozyFiles.apk'

    exec signing, (err, stdout, stderr) ->
        console.log stdout
        console.log stderr
        return done err if err
        exec aligning, (err, stdout, stderr) ->
            console.log stdout
            console.log stderr
            return done err

cordovaRun = (done) ->
    command = "./src/node_modules/.bin/cordova run android"
    exec command, (err, stdout, stderr) ->
        console.log stdout
        console.log stderr
        done()


task 'platforms', 'install cordova platforms', -> installPlatforms -> console.log "DONE"
task 'plugins', 'install cordova plugins', -> installPlugins -> console.log "DONE"
task 'plugins:update', 'update cordova plugins', -> updatePlugins -> console.log "DONE"
task 'release', 'create the released apk', -> release -> console.log "release DONE"
task 'install', 'install all application', ->
    installDependencies ->
        console.log "install dependencies DONE"
        installPlatforms ->
            console.log "install cordova platforms DONE"
            installPlugins ->
                console.log "install cordova plugins DONE"
task 'run', 'cordova run android', -> cordovaRun -> console.log "DONE"
