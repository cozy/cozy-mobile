fs     = require 'fs'
{exec} = require 'child_process'
async  = require './www-src/vendor/scripts/async'

plugins = [
    "https://github.com/aenario/cordova-external-file-open"
    "https://github.com/brodysoft/Cordova-SQLitePlugin"
    "https://git-wip-us.apache.org/repos/asf/cordova-plugin-file.git"
    "https://git-wip-us.apache.org/repos/asf/cordova-plugin-file-transfer.git"
]

platforms = ['ios', 'android']

copy = (src, target, done) ->
    r = fs.createReadStream src
    w = fs.createWriteStream target
    r.on 'error', done
    w.on 'error', done
    w.on 'close', done

    r.pipe w

copyAssets = (done) ->
    copies = [
        # android
        ['icon-36-ldpi.png', 'platforms/android/res/drawable-ldpi/icon.png']
        ['icon-48-mdpi.png', 'platforms/android/res/drawable-mdpi/icon.png']
        ['icon-72-hdpi.png', 'platforms/android/res/drawable-hdpi/icon.png']
        ['icon-96-xhdpi.png', 'platforms/android/res/drawable-xhdpi/icon.png']
        ['icon-96-xhdpi.png', 'platforms/android/res/drawable/icon.png']
        # iOs
        ['icon-57-ios.png', 'platforms/ios/Project/Resources/icons/icon.png']
        ['icon-114-ios.png', 'platforms/ios/Project/Resources/icons/icon@2x.png']
        ['icon-72-ios.png', 'platforms/ios/Project/Resources/icons/icon-72.png']
        ['icon-144-ios.png', 'platforms/ios/Project/Resources/icons/icon-72@2x.png']
    ]

    copies = copies.map (c) ->
        [src, target] = c
        return (done) ->
            copy "./res/icons/#{src}", "./#{target}", (err) ->
                console.log "#{src} -> #{target}", if err then 'KO' else 'OK'
                done()

    async.series copies, done

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
task 'assets', 'copy assets platforms', -> copyAssets -> console.log "DONE"
task 'release', 'create the released apk', -> release -> console.log "DONE"
