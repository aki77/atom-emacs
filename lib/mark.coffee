{Point, CompositeDisposable, Disposable} = require('atom')

class Mark
  MARK_MODE_CLASS = 'mark-mode'

  _marks = new WeakMap

  @for: (editor) ->
    mark = _marks.get(editor)
    unless mark
      mark = new Mark(editor)
      _marks.set(editor, mark)
    mark

  constructor: (@editor) ->
    @active = false
    @subscriptions = new CompositeDisposable
    @subscriptions.add(@editor.onDidDestroy(@destroy))

  activate: (keepSelection = false) =>
    @_clearSelection() unless keepSelection
    return if @active
    @activateSubscriptions = new CompositeDisposable
    @activateSubscriptions.add(@editor.getBuffer().onDidChange(@_onModified))
    @activateSubscriptions.add(@_addClickEventListener())
    @activateSubscriptions.add(@_addClass())
    @active = true

  deactivate: (options = {}) =>
    @active = false
    @activateSubscriptions?.dispose()
    @activateSubscriptions = null
    if options.immediate
      setImmediate(@_clearSelection)
    else
      @_clearSelection()

  destroy: =>
    return if @destroyed
    @destroyed = true
    @deactivate() if @active
    @subscriptions?.dispose()
    @subscriptions = null
    @editor = null

  isActive: ->
    @active

  exchange: ->
    return unless @isActive()
    @editor.getCursors().forEach(@_exchange)

  _exchange: (cursor) ->
    return unless cursor.selection?
    b = cursor.selection.getTailBufferPosition()
    a = cursor.getBufferPosition()
    cursor.selection.setBufferRange([a, b], {
      reversed: Point.min(a, b) is b
      autoscroll: false
    })

  _addClass: =>
    editorElement = atom.views.getView(@editor)
    editorElement.classList.add(MARK_MODE_CLASS)
    new Disposable ->
      editorElement.classList.remove(MARK_MODE_CLASS)

  _clearSelection: =>
    return unless @editor?
    return if @editor.isDestroyed()
    @editor.getCursors().forEach((cursor) ->
      cursor.clearSelection()
    )

  _onModified: (event) =>
    return if @_isIndent(event) or @_isOutdent(event)
    @deactivate(immediate: true)

  _isIndent: (event) ->
    @_isIndentOutdent(event.newRange, event.newText)

  _isOutdent: (event) ->
    @_isIndentOutdent(event.oldRange, event.oldText)

  _isIndentOutdent: (range, text) ->
    tabLength = @editor.getTabLength()
    diff = range.end.column - range.start.column
    true if diff == @editor.getTabLength() and range.start.row == range.end.row and @_checkTextForSpaces(text, tabLength)

  _checkTextForSpaces: (text, tabSize) ->
    return false unless text and text.length is tabSize

    for ch in text
      return false unless ch is " "
    true

  _addClickEventListener: =>
    callback = ({which}) =>
      # left click
      @deactivate() if which is 1
    editorElement = atom.views.getView(@editor)
    editorElement.addEventListener('mousedown', callback)
    new Disposable ->
      editorElement.removeEventListener('mousedown', callback)

module.exports = Mark
