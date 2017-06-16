## A parser to parse simple env files.
##
## Most of this is stolen from `parsecfg`, with support for sections and `:` assignment removed.

import hashes, strutils, lexbase, streams

type
  EnvEventKind* {.pure.} = enum ## enumeration of all events that may occur when parsing
    Eof,             ## end of file reached
    KeyValuePair,    ## a ``key=value`` pair has been detected
    Error            ## an error occurred during parsing

  EnvEvent* = object of RootObj ## describes a parsing event
    case kind*: EnvEventKind    ## the kind of the event
    of EnvEventKind.Eof: nil
    of EnvEventKind.KeyValuePair:
      key*, value*: string       ## contains the (key, value) pair if an option
                                 ## of the form ``--key: value`` or an ordinary
                                 ## ``key= value`` pair has been parsed.
                                 ## ``value==""`` if it was not specified in the
                                 ## configuration file.
    of EnvEventKind.Error:                 ## the parser encountered an error: `msg`
      msg*: string               ## contains the error message. No exceptions
                                 ## are thrown if a parse error occurs.

  EnvTokenKind {.pure.} = enum
    Invalid, Eof,
    Symbol, Equals
  Token = object             # a token
    kind: EnvTokenKind            # the type of the token
    literal: string          # the parsed (string) literal

  EnvParser* = object of BaseLexer ## the parser object.
    tok: Token
    filePath: string

const
  SymChars = {'a'..'z', 'A'..'Z', '0'..'9', '_', '.'}

proc rawGetTok(c: var EnvParser, tok: var Token) {.gcsafe.}

proc open*(c: var EnvParser, input: Stream, filePath: string) =
  ## initializes the parser with an input stream. `Filename` is only used
  ## for nice error messages. `lineOffset` can be used to influence the line
  ## number information in the generated error messages.
  lexbase.open(c, input)
  c.filePath = filePath
  c.tok.kind = EnvTokenKind.Invalid
  c.tok.literal = ""
  rawGetTok(c, c.tok)

proc close*(c: var EnvParser) =
  ## closes the parser `c` and its associated input stream.
  lexbase.close(c)

proc getColumn*(c: EnvParser): int =
  ## get the current column the parser has arrived at.
  result = getColNumber(c, c.bufpos)

proc getLine*(c: EnvParser): int =
  ## get the current line the parser has arrived at.
  result = c.lineNumber

proc getFilePath*(c: EnvParser): string =
  ## get the filename of the file that the parser processes.
  result = c.filePath

proc handleHexChar(c: var EnvParser, xi: var int) =
  case c.buf[c.bufpos]
  of '0'..'9':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('0'))
    inc(c.bufpos)
  of 'a'..'f':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('a') + 10)
    inc(c.bufpos)
  of 'A'..'F':
    xi = (xi shl 4) or (ord(c.buf[c.bufpos]) - ord('A') + 10)
    inc(c.bufpos)
  else:
    discard

proc handleDecChars(c: var EnvParser, xi: var int) =
  while c.buf[c.bufpos] in {'0'..'9'}:
    xi = (xi * 10) + (ord(c.buf[c.bufpos]) - ord('0'))
    inc(c.bufpos)

proc getEscapedChar(c: var EnvParser, tok: var Token) =
  inc(c.bufpos)               # skip '\'
  case c.buf[c.bufpos]
  of 'n', 'N':
    add(tok.literal, "\n")
    inc(c.bufpos)
  of 'r', 'R', 'c', 'C':
    add(tok.literal, '\c')
    inc(c.bufpos)
  of 'l', 'L':
    add(tok.literal, '\L')
    inc(c.bufpos)
  of 'f', 'F':
    add(tok.literal, '\f')
    inc(c.bufpos)
  of 'e', 'E':
    add(tok.literal, '\e')
    inc(c.bufpos)
  of 'a', 'A':
    add(tok.literal, '\a')
    inc(c.bufpos)
  of 'b', 'B':
    add(tok.literal, '\b')
    inc(c.bufpos)
  of 'v', 'V':
    add(tok.literal, '\v')
    inc(c.bufpos)
  of 't', 'T':
    add(tok.literal, '\t')
    inc(c.bufpos)
  of '\'', '"':
    add(tok.literal, c.buf[c.bufpos])
    inc(c.bufpos)
  of '\\':
    add(tok.literal, '\\')
    inc(c.bufpos)
  of 'x', 'X':
    inc(c.bufpos)
    var xi = 0
    handleHexChar(c, xi)
    handleHexChar(c, xi)
    add(tok.literal, chr(xi))
  of '0'..'9':
    var xi = 0
    handleDecChars(c, xi)
    if (xi <= 255): add(tok.literal, chr(xi))
    else: tok.kind = EnvTokenKind.Invalid
  else: tok.kind = EnvTokenKind.Invalid

proc handleCRLF(c: var EnvParser, pos: int): int =
  case c.buf[pos]
  of '\c': result = lexbase.handleCR(c, pos)
  of '\L': result = lexbase.handleLF(c, pos)
  else: result = pos

proc getString(c: var EnvParser, tok: var Token, rawMode: bool) =
  var pos = c.bufpos + 1          # skip "
  var buf = c.buf                 # put `buf` in a register
  tok.kind = EnvTokenKind.Symbol
  if (buf[pos] == '"') and (buf[pos + 1] == '"'):
    # long string literal:
    inc(pos, 2)               # skip ""
                              # skip leading newline:
    pos = handleCRLF(c, pos)
    buf = c.buf
    while true:
      case buf[pos]
      of '"':
        if (buf[pos + 1] == '"') and (buf[pos + 2] == '"'): break
        add(tok.literal, '"')
        inc(pos)
      of '\c', '\L':
        pos = handleCRLF(c, pos)
        buf = c.buf
        add(tok.literal, "\n")
      of lexbase.EndOfFile:
        tok.kind = EnvTokenKind.Invalid
        break
      else:
        add(tok.literal, buf[pos])
        inc(pos)
    c.bufpos = pos + 3       # skip the three """
  else:
    # ordinary string literal
    while true:
      var ch = buf[pos]
      if ch == '"':
        inc(pos)              # skip '"'
        break
      if ch in {'\c', '\L', lexbase.EndOfFile}:
        tok.kind = EnvTokenKind.Invalid
        break
      if (ch == '\\') and not rawMode:
        c.bufpos = pos
        getEscapedChar(c, tok)
        pos = c.bufpos
      else:
        add(tok.literal, ch)
        inc(pos)
    c.bufpos = pos

proc getSymbol(c: var EnvParser, tok: var Token) =
  var pos = c.bufpos
  var buf = c.buf
  while true:
    add(tok.literal, buf[pos])
    inc(pos)
    if not (buf[pos] in SymChars): break
  c.bufpos = pos
  tok.kind = EnvTokenKind.Symbol

proc skip(c: var EnvParser) =
  var pos = c.bufpos
  var buf = c.buf
  while true:
    case buf[pos]
    of ' ', '\t':
      inc(pos)
    of '#', ';':
      while not (buf[pos] in {'\c', '\L', lexbase.EndOfFile}): inc(pos)
    of '\c', '\L':
      pos = handleCRLF(c, pos)
      buf = c.buf
    else:
      break                   # EndOfFile also leaves the loop
  c.bufpos = pos

proc rawGetTok(c: var EnvParser, tok: var Token) =
  tok.kind = EnvTokenKind.Invalid
  setLen(tok.literal, 0)
  skip(c)
  case c.buf[c.bufpos]
  of '=':
    tok.kind = EnvTokenKind.Equals
    inc(c.bufpos)
    tok.literal = "="
  of 'r', 'R':
    if c.buf[c.bufpos + 1] == '\"':
      inc(c.bufpos)
      getString(c, tok, true)
    else:
      getSymbol(c, tok)
  of '"':
    getString(c, tok, false)
  of lexbase.EndOfFile:
    tok.kind = EnvTokenKind.Eof
    tok.literal = "[EOF]"
  else: getSymbol(c, tok)

proc errorStr*(c: EnvParser, msg: string): string =
  ## returns a properly formated error message containing current line and
  ## column information.
  result = `%`("$1($2, $3) Error: $4",
               [c.filePath, $getLine(c), $getColumn(c), msg])

proc warningStr*(c: EnvParser, msg: string): string =
  ## returns a properly formated warning message containing current line and
  ## column information.
  result = `%`("$1($2, $3) Warning: $4",
               [c.filePath, $getLine(c), $getColumn(c), msg])

proc ignoreMsg*(c: EnvParser, e: EnvEvent): string =
  ## returns a properly formated warning message containing that
  ## an entry is ignored.
  case e.kind
  of EnvEventKind.KeyValuePair: result = c.warningStr("key ignored: " & e.key)
  of EnvEventKind.Error: result = e.msg
  of EnvEventKind.Eof: result = ""

proc getKeyValPair(c: var EnvParser, kind: EnvEventKind): EnvEvent =
  if c.tok.kind == EnvTokenKind.Symbol:
    result.kind = kind
    result.key = c.tok.literal
    result.value = ""
    rawGetTok(c, c.tok)

    if c.tok.kind == EnvTokenKind.Symbol and result.key == "export":
      # skip `export`
      result.key = c.tok.literal
      rawGetTok(c, c.tok)

    if c.tok.kind == EnvTokenKind.Equals:
      rawGetTok(c, c.tok)
      if c.tok.kind == EnvTokenKind.Symbol:
        result.value = c.tok.literal
      else:
        reset result
        result.kind = EnvEventKind.Error
        result.msg = errorStr(c, "symbol expected, but found: " & c.tok.literal)
      rawGetTok(c, c.tok)
    else:
      reset result
      result.kind = EnvEventKind.Error
      result.msg = errorStr(c, "symbol expected, but found: " & c.tok.literal)
  else:
    result.kind = EnvEventKind.Error
    result.msg = errorStr(c, "symbol expected, but found: " & c.tok.literal)
    rawGetTok(c, c.tok)

proc next*(c: var EnvParser): EnvEvent =
  ## retrieves the first/next event. This controls the parser.
  case c.tok.kind
  of EnvTokenKind.Eof:
    result.kind = EnvEventKind.Eof
  of EnvTokenKind.Symbol:
    result = getKeyValPair(c, EnvEventKind.KeyValuePair)
  of EnvTokenKind.Invalid, EnvTokenKind.Equals:
    result.kind = EnvEventKind.Error
    result.msg = errorStr(c, "invalid token: " & c.tok.literal)
    rawGetTok(c, c.tok)
