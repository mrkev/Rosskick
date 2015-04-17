server  = require "./server.coffee"
settings = require "./client/package.json"
Updater = require "../update"
assert = require("assert")

server.start ->
  describe('Rosskick', function(){

    beforeEach ->
      updater = new Updater(settings)

    it 'does the thing', -> 
      updater.installOSX = (pkg, appnw, resolve, reject) ->
        console.log(pkg, appnw)
        resolve()

      updater.on "check", (err, next, info) -> 
        console.trace err if err
        console.log 'check'


        next(true)

      updater.on "download", (err, next, info) ->
        console.trace err if err
        console.log 'dl'

        next(true)

      updater.on "installed", (err, info) ->
        console.trace err if err


        console.log "Update installed"

      updater.on "download progress", (progress) ->
        console.log "#{progress.percentage}% @#{progress.speed}bps (#{progress.remaining} remaining)"
          
      updater.update().then -> 
        assert.equal(true, true);

        console.log "update done" 

      
  })


