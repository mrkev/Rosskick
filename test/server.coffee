express        = require "express"
bodyParser     = require "body-parser"
errorHandler   = require "errorhandler"
methodOverride = require "method-override"

app = express()

app.get "/", (req, res) ->
  res.redirect "/manifest.json"
  return

app.use methodOverride()
app.use bodyParser.json()
app.use bodyParser.urlencoded(extended: true)
app.use express.static(__dirname + "/server")
app.use errorHandler
  dumpExceptions: true
  showStack: true

module.exports.start = (cb) ->
  console.log "Simple static server listening at http://localhost:1800"
  app.listen 1800, cb

if require.main is module
    module.exports.start()
