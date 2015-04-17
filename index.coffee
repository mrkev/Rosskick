fs    = require('fs')
spawn = require('child_process').spawn
out   = fs.openSync('./out.log', 'a')
err   = fs.openSync('./out.log', 'a')

child = spawn 'prg', [], 
  detached: true,
  stdio: [ 'ignore', out, err ]


child.unref();

updater_nw   = require './updater_nodewebkit'
updater_tint = require './updater_tint'
