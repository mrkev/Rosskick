request = require("request")
fs      = require("fs")
rm      = require("rimraf")
path    = require("path")
crypto  = require("crypto")
Zip     = require("adm-zip")
Promise = require("es6-promise").Promise
rp      = require("request-promise")

class VerificationError extends Error
    constructor: ->
        @name = 'VerificationError'

class Ross

  constructor : (@settings) ->
    @TEMP_FOLDER = if @settings.current_os is 
      'linux' then process.execPath else process.cwd();
    @TEMP_FILENAME = "package.nw.new"
    @outputFile = path.join(path.dirname(@TEMP_FOLDER), @TEMP_FILENAME)
    
    ##
    # Function returning true if currently in test development (aka. shouldn't
    # update), false if it should update. Called before UPDATE_ENDPOINT is
    # quieried for manifest.
    @is_test_development = (() -> false)() 

    ##
    # Function returning promise to true if update process should continue,
    # false otherwise. Called only when an update for the app in the current
    # OS is available.
    @present = ((update_info)-> return new Promise((decide) -> decide true))

    ##
    # Function called when udpate process has been completed successfully.
    @notify_updated = ((update_info)-> return true)


  ##
  # Updates
  update : ->
    self = this
    return @check().then (update_info) ->
      return unless update_info 

      package_info = update_info.release[self.settings.current_os]

      return self.present(update_info).then (go) -> 
        if go
          return self.download(package_info)
          .then((pkg_inf) -> self.verify pkg_inf)
          .then(() -> self.install())
          .then(() -> self.notify_updated update_info)

  ##
  # Returns: Promise to null if no update available for current OS, or the 
  #  update object for the latest update.
  check : () ->
    self = this
    
    if @is_test_development
      console.log "Not updating. Test development."
      return Promise.resolve null

    return rp(self.settings.update.endpoint).then (updates) ->
      updates  = JSON.parse(updates)
      versions = Object.keys(updates).sort()
      
      # Could/should be externalized to allow for channels? Maybe with a
      # should_update delegate function that returns a boolean?
      latest = versions[versions.length - 1]
      if latest > self.settings.version
        return updates[latest]

      return null
      # //

  ##
  # Downloads update for selected OS.
  # Returns: Promise to the package_info of the downloaded update
  # 
  download : (package_info) ->
    self = this
    return new Promise (resolve, reject) ->
      download_stream = request(package_info.url)
      download_stream.pipe fs.createWriteStream(self.outputFile)

      download_stream.on "complete", ->
        resolve package_info
        return
      
      download_stream.on "error", (e) ->
        reject e
        return


  ##
  # Returns: Empty promise if verification was successful. 
  # Rejects: VerificationError if verification fails.
  verify : (package_info) ->
    self = this
    return new Promise (resolve, reject) ->

      hash   = crypto.createHash("SHA1")
      verify = crypto.createVerify("RSA-SHA256")

      read_stream = fs.createReadStream(self.outputFile)
      read_stream.pipe hash
      read_stream.pipe verify
      read_stream.on "end", ->
        hash.end()
        try          
          if (package_info.checksum is hash.read().toString("hex") and
              verify.verify(self.settings.update.pubkey, package_info.signature, "base64"))
            resolve true
          else
            reject new VerificationError("Verification Failed.")
        catch e
          console.error e

  ##
  # Installs donwloaded update
  # Returns: Empty promise if instalation was successful.
  install : () ->
    os = @settings.current_os
    # ## Check if path exists.
    if os is "win32" or os is "win64"
      return installWindows.apply(this)
    else if os is "linux32" or os is "linux64"
      return installLinux.apply(this)
    else if os is "osx32" or os is "osx64"
      return installOSX.apply(this)
    else
      throw new Error("OS not supported. This should be impossible.")

  ##
  # Installs downloaded update on OSX
  installOSX = () ->
    self = this
    outputDir = path.dirname(self.outputFile)
    installDir = path.join(outputDir, "app.nw")
    return new Promise (resolve, reject) ->
      
      # Remove current 
      rm installDir, (err) ->
        if err
          reject err
          return 
        
        # Extract
        pack = new Zip(self.outputFile)
        
        pack.extractAllTo installDir, true
          
        # Cleanup download
        fs.unlink self.outputFile, (err) ->
          if err
            reject err
          else
            resolve()
          return
  
        return
  
        return

  ########################### Unsupported/Unfinished ###########################
  
  ##
  # Removes temporary download data. 
  # Returns: Empty promise if cleanup was successful.
  cleanup = () -> 
    ## # 

  ##
  # Installs downloaded update on Windows
  installWindows = (updateData) ->
    self = this
    outputDir = path.dirname(@outputFile)
    installDir = path.join(outputDir, "app")
    pack = new zip(@outputFile)
    return new Promise (resolve, reject) -> 
      
      # Extract update to install directory
      pack.extractAllToAsync installDir, true, (err) ->
        if err
          reject err
          return
        
        # Cleanup
        fs.unlink downloadPath, (err) ->
          if err
            defer.reject err
          else
            defer.resolve()
          return
  
        return

  # WIP
  installLinux = (updateData) ->
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

  Updater = (options) ->
    return new Updater(options) unless this instanceof Updater
    self = this
    @options = _.defaults(options or {},
      endpoint: UPDATE_ENDPOINT
      channel: "beta"
    )
    @outputDir = (if App.settings.os is "linux" then process.execPath else process.cwd())
    @updateData = null
    return


# ## Check if running in correct directory (aka. has app.nw in it)

module.exports = Ross

  