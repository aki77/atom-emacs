{CompositeDisposable} = require 'atom'

module.exports =
class GlobalEmacsState
  # for SpecMode
  ignoreCommands = new Set([
    'editor:display-updated', 'cursor:moved', 'selection:changed'
  ])

  subscriptions: null
  lastCommand: null
  thisCommand: null

  constructor: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add(atom.commands.onWillDispatch(@logCommand))

  destroy: ->
    @subscriptions?.dispose()
    @subscriptions = null

  logCommand: ({type: command}) =>
    return if command.indexOf(':') is -1
    return if ignoreCommands.has(command)
    @lastCommand = @thisCommand
    @thisCommand = command
