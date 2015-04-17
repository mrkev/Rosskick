Rosskick
========

Note: Early pre-alpha. Only works with OSX at the moment.


# What is this?

It's a node application updater, specifically targeted towards nodewebkit apps.
It's meant to be extensible, but also a dead-easy drop-in solution for updating
apps. 

This video says it all: `TODO VIDEO`

# How do I use it?

- Watch the video above.
- Check out `TODO UI` for a simple tool that will
automatically package your application with `nwbuild`, zip it with `archiver`,
sign it with node's built-in `crypto` package, and produce the json you need
to publish your udpate.
- Browse `TODO CLEAN` for a sample app using Rosskick.


# What works? What's missing?

## Works
- OSX support
- app.nw update (aka. Update your app, not the node-webkit wrapper)

## Missing
- Windows / Linux support
- Independent helper for full app udpate (aka. replacing entire app and not just app.nw)

# Quick Info

### Manifest Sample

    {
      "0.0.0": {
        "description": "Initial release.",
        "changeLog": [
          "Airplay issue",
          "Chromecast issue",
          "Stuck on loading",
          "Stuck on subtitles download"
        ],
        "release" : {
          "osx64": {
            "url": "https://get.application.io/_updates/0_3_5_3.win.nw",
            "checksum": "6dc286f572627c9d5a7ff00ac7a9383047c0c097",
            "signature": "9ebdbf3fb71585b32817dc8eee83a1fdd5178d410d1c15549c55c7deef1b19aeafeaf554a8ba7dc091479cd6ddf9da1bf 14072dc8d3a5e4751b4cb30dbc31197d1cccb65b5d595c1c3de9532b34cc92d5e2c0b852e717679d21d73823d5b885fb3359f2241156ee8  9f5d92ddf1a279105865f3a3c8a70bf0bb300ff687cc2197e2b0e101d0c2f53a76291d0cde148df861edc54fa9d167df94188f983094aed 6bbf98accc516fdba708df15a1d3f375f285255ab019aae994984fbbbb713766ef1eb8a8c8df177756c3085fd8764829782254d0a794d94  6a026ebc578a45327a95218c4cec19fb05b5dcc5732886eee0c6ed7864e3f1df4b5f8f7603054a1a2c"
          },
          "osx32" : {...},
        }
      },
      "0.0.1" : {...}
    }
    
#### Notes
- The only *required* fields are those in `"release"`. The rest is optional / up
  to you. For this sample I thought a description / changelog were a good idea.
### Security
The following algorithms are used for the signature and the checksum
- **signature:** RSA-SHA256
- **checksum:** SHA1
