_ = require 'underscore-plus'
{CompositeDisposable, Disposable} = require 'atom'
Mark = require './mark'
CursorTools = require './cursor-tools'
{appendCopy} = require './selection'

module.exports =
class Emacs
  KILL_COMMAND = 'emacs-plus:kill-region'

  destroyed: false

  constructor: (@editor, @globalEmacsState) ->
    @editorElement = atom.views.getView(editor)
    @subscriptions = new CompositeDisposable
    @subscriptions.add(@addClass())
    @subscriptions.add(@editor.onDidDestroy(@destroy))
    @subscriptions.add(@editor.onDidChangeSelectionRange(_.debounce((event) =>
      @selectionRangeChanged(event)
    , 100)))
    # @subscriptions.add(@editor.onDidChangeSelectionRange(@selectionRangeChanged))

    # need for kill-region
    @subscriptions.add(@editor.onDidInsertText( =>
      @globalEmacsState.logCommand(type: 'editor:didInsertText')
    ))

    @registerCommands()

  destroy: =>
    return if @destroyed
    @destroyed = true
    @subscriptions.dispose()
    @subscriptions = null
    @editor = null
    @editorElement = null

  selectionRangeChanged: (event = {}) =>
    {selection, newBufferRange} = event
    return unless selection?
    return if selection.isEmpty()
    return if @destroyed
    return if selection.cursor.destroyed?

    mark = Mark.for(selection.cursor)
    unless mark.isActive()
      mark.activate()

  registerCommands: ->
    @subscriptions.add atom.commands.add @editorElement,
      'emacs-plus:append-next-kill': @appendNextKill
      'emacs-plus:backward-kill-word': @backwardKillWord
      'emacs-plus:capitalize-word': @capitalizeWord
      'emacs-plus:copy': @copy
      'emacs-plus:delete-horizontal-space': @deleteHorizontalSpace
      'emacs-plus:delete-indentation': @deleteIndentation
      'emacs-plus:exchange-point-and-mark': @exchangePointAndMark
      'emacs-plus:just-one-space': @justOneSpace
      'emacs-plus:kill-line': @killLine
      'emacs-plus:kill-region': @killRegion
      'emacs-plus:kill-whole-line': @killWholeLine
      'emacs-plus:kill-word': @killWord
      'emacs-plus:open-line': @openLine
      'emacs-plus:recenter-top-bottom': @recenterTopBottom
      'emacs-plus:set-mark': @setMark
      'emacs-plus:transpose-lines': @transposeLines
      'emacs-plus:transpose-words': @transposeWords
      'core:cancel': @deactivateCursors

  addClass: ->
    className = 'emacs-plus'
    @editorElement.classList.add(className)
    new Disposable =>
      @editorElement.classList.remove(className) if @editor.isAlive()

  appendNextKill: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    atom.notifications.addInfo('If a next command is a kill, it will append')

  backwardKillWord: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    maintainClipboard = false
    @killSelectedText((selection) ->
      selection.selectToBeginningOfWord() if selection.isEmpty()
      selection.cut(maintainClipboard) unless selection.isEmpty()
      maintainClipboard = true
    , true)

  capitalizeWord: =>
    @editor.replaceSelectedText selectWordIfEmpty: true, (text) ->
      _.capitalize(text)

  copy: =>
    @editor.copySelectedText()
    @deactivateCursors()

  deactivateCursors: =>
    for cursor in @editor.getCursors()
      Mark.for(cursor).deactivate()

  deleteHorizontalSpace: =>
    for cursor in @editor.getCursors()
      tools = new CursorTools(cursor)
      range = tools.horizontalSpaceRange()
      @editor.setTextInBufferRange(range, '')

  deleteIndentation: =>
    @editor.transact =>
      @editor.moveUp()
      @editor.joinLines()

  exchangePointAndMark: =>
    @editor.moveCursors (cursor) ->
      Mark.for(cursor).exchange()

  justOneSpace: =>
    for cursor in @editor.getCursors()
      tools = new CursorTools(cursor)
      range = tools.horizontalSpaceRange()
      @editor.setTextInBufferRange(range, ' ')

  killRegion: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    maintainClipboard = false
    @killSelectedText (selection) ->
      selection.cut(maintainClipboard, false) unless selection.isEmpty()
      maintainClipboard = true

  killWholeLine: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    maintainClipboard = false
    @killSelectedText (selection) ->
      selection.clear()
      selection.selectLine()
      selection.cut(maintainClipboard, true)
      maintainClipboard = true

  killLine: (event) =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    maintainClipboard = false
    @killSelectedText (selection) ->
      selection.selectToEndOfLine() if selection.isEmpty()
      if selection.isEmpty()
        selection.selectRight()
      selection.cut(maintainClipboard, false)
      maintainClipboard = true

  killWord: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    maintainClipboard = false
    @killSelectedText (selection) ->
      selection.selectToEndOfWord() if selection.isEmpty()
      selection.cut(maintainClipboard) unless selection.isEmpty()
      maintainClipboard = true

  openLine: =>
    @editor.insertNewline()
    @editor.moveUp()

  recenterTopBottom: =>
    minRow = Math.min((c.getBufferRow() for c in @editor.getCursors())...)
    maxRow = Math.max((c.getBufferRow() for c in @editor.getCursors())...)
    minOffset = @editorElement.pixelPositionForBufferPosition([minRow, 0])
    maxOffset = @editorElement.pixelPositionForBufferPosition([maxRow, 0])
    @editor.setScrollTop((minOffset.top + maxOffset.top - @editor.getHeight())/2)

  setMark: =>
    for cursor in @editor.getCursors()
      Mark.for(cursor).set().activate()

  transposeLines: =>
    cursor = @editor.getLastCursor()
    row = cursor.getBufferRow()

    @editor.transact =>
      tools = new CursorTools(cursor)
      if row == 0
        tools.endLineIfNecessary()
        cursor.moveDown()
        row += 1
      tools.endLineIfNecessary()

      text = @editor.getTextInBufferRange([[row, 0], [row + 1, 0]])
      @editor.deleteLine(row)
      @editor.setTextInBufferRange([[row - 1, 0], [row - 1, 0]], text)

  transposeWords: =>
    @editor.transact =>
      for cursor in @editor.getCursors()
        cursorTools = new CursorTools(cursor)
        cursorTools.skipNonWordCharactersBackward()

        word1 = cursorTools.extractWord()
        word1Pos = cursor.getBufferPosition()
        cursorTools.skipNonWordCharactersForward()
        if @editor.getEofBufferPosition().isEqual(cursor.getBufferPosition())
          # No second word - put the first word back.
          @editor.setTextInBufferRange([word1Pos, word1Pos], word1)
          cursorTools.skipNonWordCharactersBackward()
        else
          word2 = cursorTools.extractWord()
          word2Pos = cursor.getBufferPosition()
          @editor.setTextInBufferRange([word2Pos, word2Pos], word1)
          @editor.setTextInBufferRange([word1Pos, word1Pos], word2)
        cursor.setBufferPosition(cursor.getBufferPosition())

  # private
  killSelectedText: (fn, reversed = false) ->
    if @globalEmacsState.lastCommand isnt KILL_COMMAND
      return @editor.mutateSelectedText(fn)

    copyMethods = new WeakMap
    for selection in @editor.getSelections()
      copyMethods.set(selection, selection.copy)
      selection.copy = appendCopy.bind(selection, reversed)

    @editor.mutateSelectedText(fn)

    for selection in @editor.getSelections()
      originalCopy = copyMethods.get(selection)
      selection.copy = originalCopy if originalCopy

    return
