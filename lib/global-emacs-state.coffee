{CompositeDisposable} = require 'atom'
Mark = require './mark'

module.exports =
class GlobalEmacsState
  # for SpecMode
  ignoreCommands = new Set([
    'editor:display-updated', 'cursor:moved', 'selection:changed'
  ])

  subscriptions: null
  lastCommand: null
  thisCommand: null
  activateMarkCommands: new Set

  constructor: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add(atom.commands.onWillDispatch(@logCommand))
    @subscriptions.add(atom.config.observe('emacs-plus.activateMarkCommands', (value) =>
      @activateMarkCommands = new Set(value)
    ))
    @subscriptions.add(atom.commands.onWillDispatch(({type: command}) =>
      if @activateMarkCommands.has(command)
        Mark.for(atom.workspace.getActiveTextEditor()).activate()
    ))

  destroy: ->
    @subscriptions?.dispose()
    @subscriptions = null

  logCommand: ({type: command}) =>
    return if command.indexOf(':') is -1
    return if ignoreCommands.has(command)
    @lastCommand = @thisCommand
    @thisCommand = command
