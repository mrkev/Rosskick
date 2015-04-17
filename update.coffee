request  = require("request")
fs       = require("fs-extra")
path     = require("path")
crypto   = require("crypto")
Zip      = require("adm-zip")
Promise  = require("es6-promise").Promise
rp       = require("request-promise")
progress = require('progress-stream')
glob     = require('glob')
os       = require('os')

## TODO
# # ## Check if running in correct directory (aka. has app.nw in it)
# Add automatic cleanup phase. Remove upziped temp dir. 
# Make separate process.

class VerificationError extends Error
  constructor: ->
    @name = 'VerificationError'

class ImplementationError extends Error
  constructor: (@message)->
    @name = 'ImplementationError'


##
# Rosskick!
# 
# Rosskick is a general purpose updater. It sets up the framework and workflow
# running as a separate process to allow for full updates.
# 
class Ross

  ##
  # @parm settings      package.json object of app to update.
  constructor : (@settings) ->
    
    @settings.current_os = @currentOS() unless @settings.current_os    
    
    @TEMP_FOLDER   = if @settings.current_os is'linux' then process.execPath else process.cwd();
    @TEMP_FILENAME = "update.new"
    @OUTPUT_FILE   = path.join(path.dirname(@TEMP_FOLDER), @TEMP_FILENAME)

    throw new ImplementationError('No update details provided in package.json.') unless @settings.update

    ##
    # Functions to be called between each stage of update. They also decide if
    # update process should continue.
    # next: (err, next) ->
    #   [err]  error or null
    #   [next] function if err is null, undefined otherwise. next(true) will
    #          continue the update process. next(false) will halt it.
    @_on = 
        
      # Ran once update information has been queried from server.
      "check" : (err, next, info) -> 
        console.log "Checked for updates"
        return console.error(err) if err
        next(true)
      
      # Ran once update package has been downloaded
      "download" : (err, next, info) ->
        console.log "Update downloaded"
        return console.error(err) if err
        next(true)

      # Ran once update has been installed.
      "installed" : (err, info) ->
        return console.error(err) if err
        console.log "Update installed"
      
      # Called intermitently with download progress information.
      "download progress" : (progress) ->
        console.log "#{progress.percentage}% @#{progress.speed}bps (#{progress.remaining} remaining)"
      

    ## Default installers.
    #
    # Installer is a function with signature (pkg, appnw, resolve, reject)
    # pkg: path to unpackaged zip.
    # app: path to .app
    # resolve/reject: Promise returns.
    #
    @installOSX = if @nwPackage(@settings) then updater_nw.installOSX else () -> 
      throw new ImplementationError('OSX update installer not implemented')

    @installWindows = if @nwPackage(@settings) then updater_nw.installWindows else () -> 
      throw new ImplementationError('Windows update installer not implemented')

    @installLinux = if @nwPackage(@settings) then updater_nw.installLinux else () -> 
      throw new ImplementationError('Linux update installer not implemented')


  ################################ Environment. ################################

  ##
  # Retruns true if package has the format of a nodewebkit app, false otherwise.
  nwPackage : ->
    return if @settings.window then true else false

  ##
  # Returns nodewebkit OS code for current platform.
  currentOS : ->
    return switch os.platform() + os.arch()
      when 'linuxx64'  then 'linux64'
      when 'linuxx84'  then 'linux32'
      when 'darwinx64' then 'osx64' 
      when 'darwinx84' then 'osx32'
      when 'win64x64'  then 'win64'
      when 'win32x84'  then 'win32'
      else os.platform() + os.arch()

  ################################## Setters. ##################################

  ##
  # Sets event functions.
  on : (evt, fn) ->
    throw "Expected callback function" unless typeof fn is "function"
    @_on[evt] = fn


  ############################### Update Process ###############################

  ##
  # THE REAL DEAL: Updates the mcjigg.
  update : ->
    self = this
    
    update_info  = null
    package_info = null

    # 1. Check for updates
    return @check()
    .then (info) ->
      console.log '1'
      update_info = info
      
      throw new Error("Empty update manifest file.") unless update_info
      throw new Error("No 'release' for update")     unless update_info.release

      package_info = update_info.release[self.settings.current_os]
      
      throw  new Error('Update not available for current OS') unless package_info
      return new Promise((resolve) -> self._on["check"](null, resolve, update_info))
     
    .catch((err) -> self._on["check"](err, null, update_info))


    # 2. Download updates
    .then (go) ->
      return false unless go
      return self.download(package_info)
      .then((pkg_inf) -> self.verify pkg_inf)
      .then -> 
        return new Promise((res) -> self._on['download'](null, res, update_info))

    .catch((err) -> self._on['download'](err, null, update_info))


    # 3. Install the updates
    .then (go) ->
      return false unless go
      return self.install()
    
    .catch((err) -> self._on['installed'](err, null, update_info))

    # 4. Done! ^.^
    .then () -> 
      self._on['installed'](null, update_info)


  ## THE STAGES ##

  ##
  # Returns: Promise to null if no update available for current OS, or the 
  #  update object for the latest update.
  check : () ->
    self = this

    return rp(self.settings.update.endpoint).then (updates) ->
      updates  = JSON.parse(updates)
      versions = Object.keys(updates).sort()
      
      # Could/should be externalized to allow for channels? Maybe with a
      # should_update delegate function that returns a boolean? # ## USE SEMVER
      latest = versions[versions.length - 1]
      if latest > self.settings.version
        return updates[latest]

      return null

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

      .pipe fs.createWriteStream(self.OUTPUT_FILE)

  ##
  # Returns: Empty promise if verification was successful. 
  # Rejects: VerificationError if verification fails.
  verify : (package_info) ->
    self = this
    return new Promise (resolve, reject) ->

      hash   = crypto.createHash("SHA1")
      verify = crypto.createVerify("RSA-SHA256")

      read_stream = fs.createReadStream(self.OUTPUT_FILE)
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
  # Unzips downloaded package.
  # Returns: Directory of extracted zip.
  unzip : () ->
    
    # Extract
    pack = new Zip(@OUTPUT_FILE)
    dest = path.join(path.dirname(@OUTPUT_FILE), 'update')
    pack.extractAllTo dest, true

    # Cleanup download
    fs.unlinkSync @OUTPUT_FILE
    
    return dest

  ##
  # Installs donwloaded update
  # Returns: Empty promise if instalation was successful.
  install : () ->
    self = this
    os = @settings.current_os

    pkg = @unzip()
    app = process.cwd()

    
    switch os
      
      when "win32", "win64"
        return new Promise((res, rej) -> 
          self.installWin.call(self, pkg, app, res, rej))
      
      when "linux32", "linux64"
        return new Promise((res, rej) -> 
          self.installLinux.call(self, pkg, app, res, rej))
      
      when "osx32", "osx64"
        return new Promise((res, rej) -> 
          self.installOSX.call(self, pkg, app, res, rej))
      
      else
        throw new Error("OS not supported. This should be impossible.")


module.exports = Ross

  