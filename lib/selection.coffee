# TODO: Refactor
appendCopy = (reversed = false, maintainClipboard=false, fullLine=false) ->
  return if @isEmpty()

  {text: clipboardText, metadata} = atom.clipboard.readWithMetadata()
  return unless metadata?
  if metadata.selections?.length > 1
    return if metadata.selections?.length isnt @editor.getSelections().length
    maintainClipboard = true

  {start, end} = @getBufferRange()
  selectionText = @editor.getTextInRange([start, end])
  precedingText = @editor.getTextInRange([[start.row, 0], start])
  startLevel = @editor.indentLevelForLine(precedingText)

  appendTo = (_text, _indentBasis) ->
    if reversed
      _text = selectionText + _text
      _indentBasis = startLevel
    else
      _text = _text + selectionText

    {
      text: _text
      indentBasis: _indentBasis
      fullLine: false
    }

  if maintainClipboard
    index = @editor.getSelections().indexOf(this)
    {text: _text, indentBasis: _indentBasis, fullLine: _fullLine} = metadata.selections[index]
    selectionData = appendTo(_text, _indentBasis)
    newMetadata = metadata
    newMetadata.selections[index] = selectionData
    newText = newMetadata.selections.map((selection) -> selection.text).join("\n")
  else
    {indentBasis: _indentBasis, fullLine: _fullLine} = metadata
    {text: newText, indentBasis, fullLine} = appendTo(clipboardText, _indentBasis)
    newMetadata = {indentBasis, fullLine}

  # support clipboard-plus
  newMetadata.replace = true
  atom.clipboard.write(newText, newMetadata)

module.exports = {appendCopy}
