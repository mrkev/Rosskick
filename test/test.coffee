server  = require "./server.coffee"
settings = require "./client/package.json"
Updater = require "../update"
server.start ->

  updater = new Updater(settings)

  updater.installOSX = (pkg, appnw, resolve, reject) ->
    console.log(pkg, appnw)
    resolve()

  updater.on "check", (err, next, info) -> 
    return console.trace err if err
    console.log 'check'

    next(true)

  updater.on "download", (err, next, info) ->
    return console.trace err if err
    console.log 'dl'
    next(true)

  updater.on "installed", (err, info) ->
    return console.trace err if err

    console.log "Update installed"

  # updater.on "download progress", (progress) ->
  #   console.log "#{progress.percentage}% @#{progress.speed}bps (#{progress.remaining} remaining)"
      
  updater.update().then -> 
    console.log "update done" 