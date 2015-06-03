{CompositeDisposable} = require 'atom'
Emacs = require './emacs'
GlobalEmacsState = require './global-emacs-state'

module.exports =

  activate: ->
    @subscriptions = new CompositeDisposable
    @emacsObjects = new WeakMap
    @globalEmacsState = new GlobalEmacsState
    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      return if editor.mini
      unless @emacsObjects.get(editor)
        @emacsObjects.set(editor, new Emacs(editor, @globalEmacsState))

  deactivate: ->
    @subscriptions?.dispose()
    @subscriptions = null

    for editor in atom.workspace.getTextEditors()
      @emacsObjects.get(editor)?.destroy()
    @emacsObjects = null

    @globalEmacsState?.destroy()
    @globalEmacsState = null
