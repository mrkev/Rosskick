Rosskick
========

Note: Early pre-alpha. Has only been tested on OSX, and not with an acutal application yet.
## Quick Info

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
        "package" : {
          "osx": {
            "url": "https://get.application.io/_updates/0_3_5_3.win.nw",
            "checksum": "6dc286f572627c9d5a7ff00ac7a9383047c0c097",
            "signature": "9ebdbf3fb71585b32817dc8eee83a1fdd5178d410d1c15549c55c7deef1b19aeafeaf554a8ba7dc091479cd6ddf9da1bf 14072dc8d3a5e4751b4cb30dbc31197d1cccb65b5d595c1c3de9532b34cc92d5e2c0b852e717679d21d73823d5b885fb3359f2241156ee8  9f5d92ddf1a279105865f3a3c8a70bf0bb300ff687cc2197e2b0e101d0c2f53a76291d0cde148df861edc54fa9d167df94188f983094aed 6bbf98accc516fdba708df15a1d3f375f285255ab019aae994984fbbbb713766ef1eb8a8c8df177756c3085fd8764829782254d0a794d94  6a026ebc578a45327a95218c4cec19fb05b5dcc5732886eee0c6ed7864e3f1df4b5f8f7603054a1a2c"
          },
          "windows" : {...},
          "linux32" : {...},
          "linux64" : {...}
        }
      },
      "0.0.1" : {...}
    }
    
#### Notes
- The only *required* fields are those in `"package"`. The rest is optional / up to you. Add as many or as
few extra fields as you please!

### Security
The following algorithms are used for the signature and the checksum
- **signature:** RSA-SHA256
- **checksum:** SHA1

A superficial understanding of RSA is necessary (ie. don't publish your private key, know how to
generate your keys). Google it up if you're not familiar with RSA. Hint: you can generate keys with
`ssh-keygen`.


## Getting Started

`coming soon... see /sample/client for sample usage`

## Publishing an update
1. Package your update builds. Put them online. 
2. Add a new entry to `manifest.json`. 
3. Sign your update using
    
        coffee sign.coffee -k <key> -f <update.zip>

  where <key> is the path to your private key file and <update.zip> is the path
  to the packaged update. This will give you the `signature` and the `checksum`
  for each package to put on the manfest (see the sample).

4. Publish your manifest.

Done.



