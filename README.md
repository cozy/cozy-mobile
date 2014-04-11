# [Cozy](http://cozy.io) Mobile client

This is the native mobile client for Cozy.

## Install

Get it from the app store or the play store.

## Built with
- cordova

## Hack

    git clone https://github.com/aenario/cozy-files-mobile
    sudo npm install -g cordova coffee-script brunch
    # see cordova doc on how to set up the SDKs
    cake platforms && cake plugins && cake assets
    # don't mind error message for the other plaform



Make your changes in www-src
Launch in a terminal
    
    cd www-src
    npm install
    brunch w

To run on device / emulator
    
    cordova run android
    cordova run ios

To run in browser,
- start chrome with --disable-web-security
- open www/index.html
- in browser's console run
```
window.isBrowserDebugging = true
document.dispatchEvent(new Event('deviceready'));
```

Expect all things binary-related to fail in browser.



## License

Cozy Mobile Client is developed by Cozy Cloud and distributed under the AGPL v3 license.

## What is Cozy?

![Cozy Logo](https://raw.github.com/mycozycloud/cozy-setup/gh-pages/assets/images/happycloud.png)

[Cozy](http://cozy.io) is a platform that brings all your web services in the
same private space.  With it, your web apps and your devices can share data
easily, providing you
with a new experience. You can install Cozy on your own hardware where no one
profiles you.

## Community

You can reach the Cozy Community by:

* Chatting with us on IRC #cozycloud on irc.freenode.net
* Posting on our [Forum](https://groups.google.com/forum/?fromgroups#!forum/cozy-cloud)
* Posting issues on the [Github repos](https://github.com/mycozycloud/)
* Mentioning us on [Twitter](http://twitter.com/mycozycloud)
