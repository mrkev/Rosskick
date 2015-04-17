module.exports = {
  
  ##
  # Installs downloaded update on OSX
  # 
  # ## Unpack zip automatically.
  nw_installOSX : (pkg, appnw, resolve, reject) ->
    
    dst = path.join(appnw, '../') #.app/Contents/Resources

    try
      # Find .app
      dlapp = glob.sync(path.join(pkg, "*.app"))[0]
      throw new Error('No .app found on update archive') unless dlapp
      src = path.join(dlapp, 'Contents/Resources')

      # Remove current 
      fs.removeSync dst

      # Move 
      fs.rename(src, dst, (err) ->
        if err
          console.log "Fatal error: Update didn't finish correctly. Redownload app T.T"
          
          throw err unless reject
          reject err

        else
          resolve true
      )

    catch e
      throw err unless reject
      reject e


  ########################### Unsupported/Unfinished ###########################

  ##
  # Installs downloaded update on Windows
  nw_installWindows : (pkg, appnw, resolve, reject) ->
    self = this
    outputDir = path.dirname(@outputFile)
    installDir = path.join(outputDir, "app")
    pack = new zip(@outputFile)
    
    return new Promise (resolve, reject) -> 
      
      # Extract update to install directory
      pack.extractAllTo installDir, true
        
      # Cleanup
      fs.unlink downloadPath, (err) ->
        if err
          defer.reject err
        else
          defer.resolve()
        return

      return

  # WIP
  nw_installLinux : (pkg, appnw, resolve, reject) ->
    
    outputDir = path.dirname(@outputFile)
    packageFile = path.join(outputDir, "package.nw")
    
    fs.rename packageFile, path.join(outputDir, "package.nw.old"), (err) ->
      if err
        reject err
        return
      
      # -> working 000
      fs.rename downloadPath, packageFile, (err) ->
        if err
          
          # Sheeet! We got a booboo :(
          # Quick! Lets erase it before anyone realizes!
          if fs.existsSync(downloadPath)
            fs.unlink downloadPath, (err) ->
              if err
                defer.reject err
              else
                fs.rename path.join(outputDir, "package.nw.old"), packageFile, (err) ->
                  
                  # err is either an error or undefined, so its fine not to check!
                  defer.reject err
                  return

              return

          else
            defer.reject err
        
        else
          fs.unlink path.join(outputDir, "package.nw.old"), (err) ->
            if err
              
              # This is a non-fatal error, should we reject?
              defer.reject err
            else
              defer.resolve()
            return

        return

      return

    defer.promise
}
