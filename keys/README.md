# Generate signed release (Cozy staff only)

We use `fastlane` to generate, sign, upload release :package:.
See more information on `fastlane/README.md`.


## Android

Place to `android` folder this files:

    cozy-play-store.keystore
    cozy-play-store.password
    cozy-play-store.json

Now you can use the npm command to create android release:

    npm run release:android


## iOS

All keys was imported by `fastlane` automatically.


### Internal

### :family: User on testflight

Internal users go to [iTunes Connect](https://itunesconnect.apple.com/WebObjects/iTunesConnect.woa/ra/ng/users_roles).

External users:

    # Add user
    pilot add email@invite.com

    # Find a tester
    pilot find email@invite.com

    # Remove user
    pilot remove email@invite.com
