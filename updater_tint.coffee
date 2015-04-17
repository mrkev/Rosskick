module.exports = {
  
  ##
  # Installs downloaded update on OSX
  # 
  # Unpack zip automatically.
  nw_installOSX : (pkg, appnw, resolve, reject) ->

    console.log 'Installing for OSX:', pkg, '->', appnw

  ########################### Unsupported/Unfinished ###########################

  nw_installWindows : (pkg, appnw, resolve, reject) ->
    console.log 'Installing for Windows:', pkg, '->', appnw

  nw_installLinux : (pkg, appnw, resolve, reject) ->
    console.log 'Installing for Linux:', pkg, '->', appnw

}
