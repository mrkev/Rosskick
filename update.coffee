request  = require("request")
fs       = require("fs-extra")
path     = require("path")
crypto   = require("crypto")
Zip      = require("adm-zip")
Promise  = require("es6-promise").Promise
rp       = require("request-promise")
progress = require('progress-stream')
glob     = require 'glob'


class VerificationError extends Error
    constructor: ->
        @name = 'VerificationError'

class Ross

  constructor : (@settings) ->
    @TEMP_FOLDER = if @settings.current_os is 
      'linux' then process.execPath else process.cwd();
    @TEMP_FILENAME = "package.nw.new"
    @outputFile = path.join(path.dirname(@TEMP_FOLDER), @TEMP_FILENAME)

    @settings.current_os = @currentOS() unless @settings.current_os
    

    ##
    # Functions to be called between each stage of update. They also decide if
    # update process should continue.
    # next: (err, next) ->
    #   [err]  error or null
    #   [next] function if err is null, undefined otherwise. next(true) will
    #          continue the update process. next(false) will halt it.
    @_on = 
      "check" : (err, next, info) -> 
        console.log "Checked for updates"
        return console.error(err) if err
        next(true)
      "download" : (err, next, info) ->
        console.log "Update downloaded"
        return console.error(err) if err
        next(true)
      "download progress" : (progress) ->
        console.log "#{progress.percentage}% @#{progress.speed}bps (#{progress.remaining} remaining)"
      "installed" : (err, info) ->
        return console.error(err) if err
        console.log "Update installed"

  currentOS : ->
    return switch [os.platform(), os.arch()]
      when ['linux',  'x64'] then 'linux64'
      when ['linux',  'x84'] then 'linux32'
      when ['darwin', 'x64'] then 'osx64'
      when ['darwin', 'x84'] then 'osx32'
      when ['win64',  'x64'] then 'win64'
      when ['win32',  'x84'] then 'win32'

  ##
  # Sets event functions.
  on : (evt, fn) ->
    throw "Expected callback function" unless typeof fn is "function"
    @_on[evt] = fn


  ############################### Update Process ###############################

  ##
  # Updates the mcjigg.
  update : ->
    self = this

    update_info  = null
    package_info = null


    # Check for updates
    return @check()
    .then (info) ->
      update_info = info
      
      throw new Error("Empty update manifest file.") unless update_info
      throw new Error("No 'release' for update")     unless update_info.release

      package_info = update_info.release[self.settings.current_os]
      
      throw  new Error('Update not available for current OS') unless package_info
      return new Promise((resolve) -> self._on["check"](null, resolve, update_info))
     
    .catch((err) -> self._on["check"](err, null, update_info))


    # Download updates
    .then (go) ->
      return false unless go
      return self.download(package_info)
      .then((pkg_inf) -> self.verify pkg_inf)
      .then -> 
        return new Promise((res) -> self._on['download'](null, res, update_info))

    .catch((err) -> self._on['download'](err, null, update_info))


    # Install the updates
    .then (go) ->
      return false unless go
      return self.install()
    
    .catch((err) -> self._on['install'](err, null, update_info))

    # Done! 
    .then (good) -> 
      self._on['install'](null, update_info) if good


  ##
  # Returns: Promise to null if no update available for current OS, or the 
  #  update object for the latest update.
  check : () ->
    self = this

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
      prog = progress(
        time: 1000
      )

      prog.on "progress", (progress) -> 
        self._on['download progress'](progress)
        return

      download_stream = request.get(package_info.url)
      
      .on('response', (response) ->
        console.log response.headers['content-type']
        try
          prog.setLength parseInt(response.headers['content-length'])
        catch e
          throw new Error 'Server returned invalid HTTP content-length header' 
      )
      
      .on("complete", ->
        resolve package_info
        return
      )

      .on("error", (e) ->
        reject e
        return
      )

      .pipe fs.createWriteStream(self.outputFile)



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
    self = this
    os = @settings.current_os
    # ## Check if path exists.
    
    switch os
      
      when "win32", "win64"
        return new Promise((res, rej) -> installWin.call(self, res, rej)) 
      
      when "linux32", "linux64"
        return new Promise((res, rej) -> installLinux.call(self, res, rej))
      
      when "osx32", "osx64"
        return new Promise((res, rej) -> installOSX.call(self, res, rej))
      
      else
        throw new Error("OS not supported. This should be impossible.")

  ##
  # Installs downloaded update on OSX
  # 
  # ## Unpack zip automatically.
  installOSX = (resolve, reject) ->
    self = this
    # process.cwd() -> 
    installDir = process.cwd() # .app/Contents/Resources/app.nw
    tempDir = path.join(process.cwd(), "../../Update") # .app/Contents/update

    dlapp = glob.sync(tempDir + "/*.app")[0]
    
    zip = self.outputFile 
    src = path.join(dlapp, 'Contents/Resources')
    dst = path.join(installDir, '../') #.app/Contents/Resources

    console.log src, '->', dst

    try

      # Extract
      pack = new Zip(self.outputFile)
      pack.extractAllTo tempDir, true

      # Cleanup download
      fs.unlinkSync zip

      # Remove current 
      fs.removeSync dst

      # Move 
      fs.rename(src, dst, (err) ->
        if err
          console.log "Fatal error: Update didn't finish correctly. Redownload app T.T"
          reject err
        else
          resolve true
      )

    catch e
      reject e

  ########################### Unsupported/Unfinished ###########################

  ##
  # Installs downloaded update on Windows
  installWindows = (updateData) ->
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

# ## Check if running in correct directory (aka. has app.nw in it)

module.exports = Ross

  