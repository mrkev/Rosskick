Updater = require "../../update.coffee"
settings = require "./packagee.json"
settings.current_os = "osx"
updater = new Updater(settings)
updater.update().then(-> console.log "update successful")