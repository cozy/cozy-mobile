# :cloud: [Cozy Cloud][0] Mobile client

[![Build Status][1]][2]
[![Dependency Status][3]][4]
[![Code Climate][5]][6]

This is the native mobile client for Cozy.


## :rocket: Install

Get it from the [Google Play Store][7],
or on [Aptoide Store][8]
or head over to the [Releases page][9].


## :boat: Compile yourself

### :wrench: Requirement

- Node v4.4.7
- Android SDK 23.0.3 to deploy on android
- Xcode 7.3.1 to deploy on ios

Necessary path:

    export ANDROID_HOME="/path/to/android-sdk-linux"
    export PATH="$PATH:$ANDROID_HOME/tools"
    export PATH="$PATH:$ANDROID_HOME/build-tools/23.0.3"
    export PATH="$PATH:$ANDROID_HOME/platform-tools"


### :package: Compile from source

    git clone https://github.com/cozy/cozy-mobile
    cd cozy-mobile/src
    npm install
    npm run build

or if you develop :loop::

    npm run watch


### :helicopter: Deploy

After that, you can deploy with one of these commands (always from `src`
folder):

    npm run android
    npm run android-emulator
    npm run ios
    npm run ios-emulator


### :warning: Android bug

You need to be aware that, some times, there is a special case when testing on
real device, where the error
`Android Cannot access org.apache.http.client.HttpClient` can happen.
It can be solved by adding into gradle in android part:

    // path : platforms/android/build.gradle

    android {
        useLibrary 'org.apache.http.legacy'    // <-- this
        sourceSets {
            ...


### :books: Resource for cordova installation

 - [ubuntu todolist][10]
 - [cordova manual][11]


## :heart: Contribute :heart:


### :speech_balloon: Comments & notes

Come chatting with me (@kosssi) on IRC #cozycloud on irc.freenode.net or on
[cozy forum][12] to suggest new feature or report a
problem. I'm very happy to see you. :heart_eyes:

You can add a comment with note on [Google Play][7] or [Aptoide][8].


### :book: Translate with Transifex

Transifex can be used the same way as git. It can push or pull translations. The
config file in the .tx repository configure the way Transifex is working : it
will get the json files from the client/app/locales repository.
If you want to learn more about how to use this tool, I'll invite you to check
 [this][13] tutorial.

    // import
    tx pull
    // export
    tx push -s


### :tada: Development

We have [some issues][14] which await
you. The label `first contribution` is more simple. :hatching_chick:


## License

Cozy Mobile Client is developed by Cozy Cloud and distributed under the LGPL v3
license.


## What is Cozy?

![Cozy Logo][15]

[Cozy][0] is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you
with a new experience. You can install Cozy on your own hardware where no one
profiles you.


## Community

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum][12]
* Posting issues on the [Github repos][16]
* Mentioning us on [Twitter][17]


[0]:  https://cozy.io
[1]:  https://travis-ci.org/cozy/cozy-mobile.svg?branch=master
[2]:  https://travis-ci.org/cozy/cozy-mobile
[3]:  https://www.versioneye.com/user/projects/575534e27757a0003bd4b117/badge.svg?style=flat-square
[4]:  https://www.versioneye.com/user/projects/575534e27757a0003bd4b117
[5]:  https://codeclimate.com/github/cozy/cozy-mobile/badges/gpa.svg
[6]:  https://codeclimate.com/github/cozy/cozy-mobile
[7]:  https://play.google.com/store/apps/details?id=io.cozy.files_client
[8]:  https://cozy.store.aptoide.com/app/market/io.cozy.files_client/103058/19682485/Cozy
[9]:  https://github.com/cozy/cozy-mobile/releases
[10]: http://askubuntu.com/questions/318246/complete-installation-guide-for-android-sdk-adt-bundle-on-ubuntu
[11]: https://cordova.apache.org/docs/en/latest/guide/platforms/android/index.html
[12]: https://forum.cozy.io
[13]: http://docs.transifex.com/introduction/
[14]: https://github.com/cozy/cozy-mobile/issues
[15]: https://raw.github.com/cozy/cozy-setup/gh-pages/assets/images/happycloud.png
[16]: https://github.com/cozy/
[17]: https://twitter.com/mycozycloud
