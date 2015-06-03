{CompositeDisposable} = require 'atom'
AtomicEmacs = require './atomic-emacs'
GlobalEmacsState = require './global-emacs-state'

module.exports =

  activate: ->
    @subscriptions = new CompositeDisposable
    @atomicEmacsObjects = new WeakMap
    @globalEmacsState = new GlobalEmacsState
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      return if editor.mini
      unless @atomicEmacsObjects.get(editor)
        @atomicEmacsObjects.set(editor, new AtomicEmacs(editor, @globalEmacsState))

  deactivate: ->
    @subscriptions?.dispose()
    @subscriptions = null

    for editor in atom.workspace.getTextEditors()
      @atomicEmacsObjects.get(editor)?.destroy()
    @atomicEmacsObjects = null

    @globalEmacsState?.destroy()
    @globalEmacsState = null
