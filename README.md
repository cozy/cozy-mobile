# [Cozy](http://cozy.io) Mobile client

[![Build Status](https://travis-ci.org/cozy/cozy-mobile.svg)](https://travis-ci.org/cozy/cozy-mobile)
[![Dependency Status](https://www.versioneye.com/user/projects/565486a3ff016c003300183a/badge.svg)](https://www.versioneye.com/user/projects/565486a3ff016c003300183a)
[![Code Climate](https://codeclimate.com/github/cozy/cozy-mobile/badges/gpa.svg)](https://codeclimate.com/github/cozy/cozy-mobile)
[![Test Coverage](https://codeclimate.com/github/cozy/cozy-mobile/badges/coverage.svg)](https://codeclimate.com/github/cozy/cozy-mobile/coverage)

This is the native mobile client for Cozy.

## Install

Get it from the play store.
Or head over to the [Releases page](https://github.com/cozy/cozy-mobile/releases)

## Built with

- cordova

## Hack

    git clone https://github.com/cozy/cozy-mobile
    sudo npm install -g cordova coffee-script brunch
    # see cordova doc on how to set up the SDKs
    cake platforms && cake plugins
    # don't mind error message for the other plaform


Make your changes in www-src, use brunch to compile in wwww

    cd www-src
    npm install
    brunch w

To run on device / emulator

    cordova run android
    cordova run ios

To run in browser,
- start chrome with --disable-web-security --allow-file-access-from-files
- open www/index.html
- in browser's console run
```
window.isBrowserDebugging = true
document.dispatchEvent(new Event('deviceready'));
```

Expect all things binary-related to fail in browser.

If you want to test on your Android device directly, please install the Android SDK http://developer.android.com/sdk/index.html. Then enable USB debugging and `cordova run android` will run the application within your phone instead of from the emulator.

## Contribute with Transifex

Transifex can be used the same way as git. It can push or pull translations. The config file in the .tx repository configure the way Transifex is working : it will get the json files from the client/app/locales repository.
If you want to learn more about how to use this tool, I'll invite you to check [this](http://docs.transifex.com/introduction/) tutorial.

## License

Cozy Mobile Client is developed by Cozy Cloud and distributed under the AGPL v3 license.

## What is Cozy?

![Cozy Logo](https://raw.github.com/cozy/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you
with a new experience. You can install Cozy on your own hardware where no one
profiles you.

## Community

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum](https://forum.cozy.io/)
* Posting issues on the [Github repos](https://github.com/cozy/)
* Mentioning us on [Twitter](http://twitter.com/mycozycloud)
