{CompositeDisposable} = require 'atom'

module.exports =
class GlobalEmacsState
  subscriptions: null
  lastCommand = null
  thisCommand = null

  constructor: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add(atom.commands.onWillDispatch(@logCommand))

  destroy: ->
    @subscriptions?.dispose()
    @subscriptions = null

  logCommand: ({type: command}) =>
    return if command.indexOf(':') is -1
    @lastCommand = @thisCommand
    @thisCommand = command

    # console.log @thisCommand, @lastCommand if atom.devMode
