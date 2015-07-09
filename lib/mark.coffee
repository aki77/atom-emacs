{Point, CompositeDisposable, Disposable} = require('atom')

# Represents an Emacs-style mark.
#
# Get the mark for a cursor with Mark.for(cursor). If the cursor has no mark
# yet, one will be created, and set to the cursor's position.
#
# The can then be set() at any time, which will move to where the cursor is.
#
# It can also be activate()d and deactivate()d. While active, the region between
# the mark and the cursor is selected, and this selection is updated as the
# cursor is moved. If the buffer is edited, the mark is automatically
# deactivated.
class Mark
  MARK_MODE_CLASS = 'mark-mode'

  _marks = new WeakMap

  @for: (cursor) ->
    mark = _marks.get(cursor)
    unless mark
      mark = new Mark(cursor)
      _marks.set(cursor, mark)
    mark

  constructor: (@cursor) ->
    @editor = @cursor.editor

    if @cursor.selection?.marker?
      @marker = @cursor.selection.marker
    else
      @marker = @editor.markBufferPosition(@cursor.getBufferPosition())

    @active = false
    @updating = false
    @destroyed = false
    @markerTailBufferPosition = null
    @subscriptions = new CompositeDisposable()
    @subscriptions.add(@cursor.onDidDestroy(@_destroy))

  set: ()->
    @deactivate()
    @marker.setHeadBufferPosition(@cursor.getBufferPosition())
    @

  setBufferRange: (range, options = {}) ->
    @deactivate()
    @activate()

    if options.reversed
      start = range.end
      end  = range.start
    else
      {start, end} = range

    @marker.setHeadBufferPosition(start)
    @_updateSelection(newBufferPosition: end)

  getBufferPosition: ->
    @marker.getHeadBufferPosition()

  activate: ->
    return if @active
    @marker.plantTail()
    @markerTailBufferPosition = @marker.getTailBufferPosition()
    @markerSubscriptions = new CompositeDisposable()
    @markerSubscriptions.add(@cursor.onDidChangePosition(@_updateSelection))
    @markerSubscriptions.add(@editor.getBuffer().onDidChange(@_onModified))
    @markerSubscriptions.add(@_addClickEventListener())
    @markerSubscriptions.add(@_addClass())
    @active = true

  deactivate: ->
    if @active
      @active = false
      @markerTailBufferPosition = null
      @markerSubscriptions?.dispose()
      @markerSubscriptions = null
    @cursor.clearSelection() unless @marker.isDestroyed()

  isActive: ->
    @active

  exchange: ->
    return unless @isActive()
    b = @marker.getTailBufferPosition()
    a = @cursor.getBufferPosition()
    @updating = true
    @cursor.selection.setBufferRange([a, b], {
      reversed: Point.min(a, b) is b
      autoscroll: false
    })
    @markerTailBufferPosition = a
    @updating = false

  _addClass: =>
    editorElement = atom.views.getView(@editor)
    editorElement.classList.add(MARK_MODE_CLASS)
    new Disposable =>
      unless @editor.getCursors().some((cursor) -> Mark.for(cursor).isActive())
        editorElement.classList.remove(MARK_MODE_CLASS)

  _addClickEventListener: =>
    callback = ({which}) =>
      # left click
      @deactivate() if which is 1
    editorElement = atom.views.getView(@editor)
    editorElement.addEventListener('mousedown', callback)
    new Disposable ->
      editorElement.removeEventListener('mousedown', callback)

  _destroy: =>
    return if @destroyed
    @destroyed = true
    @deactivate() if @active
    @marker.destroy() unless @marker.isDestroyed()
    @subscriptions?.dispose()
    @subscriptions = null
    @editor = null
    @cursor = null
    @marker = null

  _updateSelection: (event) =>
    # Updating the selection updates the cursor marker, so guard against the
    # nested invocation.
    return if @updating
    {newBufferPosition} = event
    @updating = true
    try
      if @cursor.selection.isEmpty()
        if @marker.getBufferRange().isEmpty()
          a = @markerTailBufferPosition
        else
          a = @marker.getTailBufferPosition()
      else
        a = @cursor.selection.getTailBufferPosition()

      b = newBufferPosition
      @cursor.selection.setBufferRange([a, b], {
        reversed: Point.min(a, b) is b
        autoscroll: false
      })
    finally
      @updating = false

  _onModified: (event) =>
    # necessary for multiple cursors
    {newRange} = event
    return unless newRange.containsPoint(@cursor.getBufferPosition())

    return if @_isIndent(event) or @_isOutdent(event)
    @deactivate()

  _isIndent: (event)->
    @_isIndentOutdent(event.newRange, event.newText)

  _isOutdent: (event)->
    @_isIndentOutdent(event.oldRange, event.oldText)

  _isIndentOutdent: (range, text)->
    tabLength = @editor.getTabLength()
    diff = range.end.column - range.start.column
    true if diff == @editor.getTabLength() and range.start.row == range.end.row and @_checkTextForSpaces(text, tabLength)

  _checkTextForSpaces: (text, tabSize)->
    return false unless text and text.length is tabSize

    for ch in text
      return false unless ch is " "
    true

module.exports = Mark
