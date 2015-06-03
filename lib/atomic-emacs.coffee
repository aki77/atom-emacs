_ = require 'underscore-plus'
{CompositeDisposable, Disposable} = require 'atom'
Mark = require './mark'
CursorTools = require './cursor-tools'
{appendCopy} = require './selection'

module.exports =
class AtomicEmacs
  KILL_COMMAND = 'atomic-emacs:kill-region'

  destroyed: false

  constructor: (@editor, @globalEmacsState) ->
    @editorElement = atom.views.getView(editor)
    @subscriptions = new CompositeDisposable
    @subscriptions.add(@editor.onDidDestroy(@destroy))
    @subscriptions.add(@editor.onDidChangeSelectionRange(_.debounce((event) =>
      @selectionRangeChanged(event)
    , 100)))

    # need for kill-region
    @subscriptions.add(@editor.onDidInsertText( =>
      @globalEmacsState.logCommand(type: 'editor:didInsertText')
    ))

    @registerCommands()

  destroy: =>
    return if @destroyed
    @destroyed = true
    @subscriptions.dispose()
    @editor = null

  selectionRangeChanged: ({selection, newBufferRange} = {}) ->
    return unless selection?
    return if selection.isEmpty()
    return if @destroyed
    return if selection.cursor.destroyed?

    mark = Mark.for(selection.cursor)
    mark.setBufferRange(newBufferRange) unless mark.isActive()

  registerCommands: ->
    @subscriptions.add atom.commands.add @editorElement,
      'atomic-emacs:append-next-kill': @appendNextKill
      'atomic-emacs:backward-kill-word': @backwardKillWord
      'atomic-emacs:backward-paragraph': @backwardParagraph
      'atomic-emacs:backward-word': @backwardWord
      'atomic-emacs:copy': @copy
      'atomic-emacs:delete-horizontal-space': @deleteHorizontalSpace
      'atomic-emacs:delete-indentation': @deleteIndentation
      'atomic-emacs:exchange-point-and-mark': @exchangePointAndMark
      'atomic-emacs:forward-paragraph': @forwardParagraph
      'atomic-emacs:forward-word': @forwardWord
      'atomic-emacs:just-one-space': @justOneSpace
      'atomic-emacs:kill-line': @killLine
      'atomic-emacs:kill-region': @killRegion
      'atomic-emacs:kill-whole-line': @killWholeLine
      'atomic-emacs:kill-word': @killWord
      'atomic-emacs:open-line': @openLine
      'atomic-emacs:recenter-top-bottom': @recenterTopBottom
      'atomic-emacs:set-mark': @setMark
      'atomic-emacs:transpose-chars': @transposeChars
      'atomic-emacs:transpose-lines': @transposeLines
      'atomic-emacs:transpose-words': @transposeWords
      'core:cancel': @deactivateCursors

  appendNextKill: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    atom.notifications.addInfo('If a next command is a kill, it will append')

  backwardKillWord: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    maintainClipboard = false
    @killSelectedText((selection) ->
      selection.modifySelection ->
        if selection.isEmpty()
          cursorTools = new CursorTools(selection.cursor)
          cursorTools.skipNonWordCharactersBackward()
          cursorTools.skipWordCharactersBackward()
        selection.cut(maintainClipboard) unless selection.isEmpty()
      maintainClipboard = true
    , true)

  backwardWord: =>
    @editor.moveCursors (cursor) ->
      tools = new CursorTools(cursor)
      tools.skipNonWordCharactersBackward()
      tools.skipWordCharactersBackward()

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

  forwardWord: =>
    @editor.moveCursors (cursor) ->
      tools = new CursorTools(cursor)
      tools.skipNonWordCharactersForward()
      tools.skipWordCharactersForward()

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
      fullLine = false
      selection.selectToEndOfLine() if selection.isEmpty()
      if selection.isEmpty()
        selection.selectLine()
        fullLine = true
      selection.cut(maintainClipboard, fullLine)
      maintainClipboard = true

  killWord: =>
    @globalEmacsState.thisCommand = KILL_COMMAND
    maintainClipboard = false
    @killSelectedText (selection) ->
      selection.modifySelection ->
        if selection.isEmpty()
          cursorTools = new CursorTools(selection.cursor)
          cursorTools.skipNonWordCharactersForward()
          cursorTools.skipWordCharactersForward()
        selection.cut(maintainClipboard)
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

  transposeChars: =>
    @editor.transpose()
    editor.moveRight()

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

  backwardParagraph: =>
    for cursor in @editor.getCursors()
      currentRow = cursor.getBufferPosition().row

      break if currentRow <= 0

      cursorTools = new CursorTools(cursor)
      blankRow = cursorTools.locateBackward(/^\s+$|^\s*$/).start.row

      while currentRow == blankRow
        break if currentRow <= 0

        cursor.moveUp()

        currentRow = cursor.getBufferPosition().row
        blankRange = cursorTools.locateBackward(/^\s+$|^\s*$/)
        blankRow = if blankRange then blankRange.start.row else 0

      rowCount = currentRow - blankRow
      cursor.moveUp(rowCount)

  forwardParagraph: =>
    lineCount = @editor.buffer.getLineCount() - 1

    for cursor in @editor.getCursors()
      currentRow = cursor.getBufferPosition().row
      break if currentRow >= lineCount

      cursorTools = new CursorTools(cursor)
      blankRow = cursorTools.locateForward(/^\s+$|^\s*$/).start.row

      while currentRow == blankRow
        cursor.moveDown()

        currentRow = cursor.getBufferPosition().row
        blankRow = cursorTools.locateForward(/^\s+$|^\s*$/).start.row

      rowCount = blankRow - currentRow
      cursor.moveDown(rowCount)

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
