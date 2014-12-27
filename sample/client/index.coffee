Updater = require "../../update.coffee"
settings = require "./package.json"
settings.current_os = "osx64"
updater = new Updater(settings)
updater.update().then(-> console.log "update successful")