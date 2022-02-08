## Loads environment variables from `.env`.

import std/streams, std/strtabs, std/strscans, std/os, std/strutils

type
  ParseError* = object of CatchableError
    ## Exception thrown if parsing fails.

proc processEnvFile(stream: Stream, overwrite: bool): void =
  var variables = newStringTable()

  var 
    lineNumber: int = 1
    line: string = ""
    inMultiLine: bool = false
    multilineKey: string = ""
    multilineValueBuffer: string = ""
  while stream.readLine(line):
    if len(line) > 0 and line[0] == '#':
      # comment, ignored
      continue

    if inMultiLine:
      var value: string
      if line == "\"\"\"":
        inMultiLine = false
        variables[multilineKey] = multilineValueBuffer
      elif scanf(line, "$*\"\"\"", value):
        multilineValueBuffer.add('\n')
        multilineValueBuffer.add(value)
        inMultiLine = false
        variables[multilineKey] = multilineValueBuffer
      else:
        multilineValueBuffer.add('\n')
        multilineValueBuffer.add(line)
    else:
      if isEmptyOrWhitespace(line):
        continue

      var
        key: string
        value: string
      if scanf(line, "$w$.", key) or scanf(line, "export $w$.", key):
        # key, no value
        discard
      elif scanf(line, "$w=\"\"\"$*", key, value) or scanf(line, "export $w=\"\"\"$*", key, value):
        # key, multiline string start
        inMultiLine = true
        multilineKey = key
        multilineValueBuffer = value
        continue
      elif scanf(line, "$w=\"$*\"", key, value) or scanf(line, "export $w=\"$*\"", key, value):
        # key, quoted value
        discard
      elif scanf(line, "$w=$*", key, value) or scanf(line, "export $w=$*", key, value):
        # key, unqouted value
        discard
      else:
        raise newException(ParseError, "Parse error, line: " & $lineNumber & "; line: " & line)

      variables[key] = value
      inc(lineNumber)

  for k, v in variables:
    if overwrite or not existsEnv(k):
      putEnv(k, v)

proc load*(stream: Stream): void =
  ## Load environment variables from the given stream. Existing environment variables will not be overwritten.
  ## 
  ## The stream should contain a correctly formatted `.env` file.
  processEnvFile(stream, false)

proc overload*(stream: Stream): void =
  ## Load environment variables from the given stream. Existing environment variables will be overwritten.
  ## 
  ## The stream should contain a correctly formatted `.env` file.
  processEnvFile(stream, true)

proc loadFromFile(directory: string, filename: string, overwrite: bool, bufferSize: int): void =
  let dir = if len(directory) == 0:
    getCurrentDir()
  else:
    directory

  if not dirExists(dir):
    raise newException(IOError, "Directory does not exist: " & dir)

  # Check if the `directory` path is actually a file path. If so, use it.
  let fileInfo = getFileInfo(dir)
  let filePath = if fileInfo.kind in {pcFile, pcLinkToFile}:
    dir
  else:
    var file = fileName
    if len(file) < 1:
      file = ".env"

    let path = joinPath(dir, filename)

    if not fileExists(path):
      raise newException(IOError, "Path does not exist: " & path)

    path

  var strm = newFileStream(filePath, fmRead, bufferSize)

  if strm == nil:
    raise newException(IOError, "Failed to open file: " & filePath)

  try:
    processEnvFile(strm, overwrite)
  finally:
    strm.close()

proc load*(directory: string = "", filename: string = ".env", bufferSize: int = 4096): void =
  ## Load environment variables from the given directory using the given filename. Existing environment variables will not be overwritten.
  loadFromFile(directory, filename, false, bufferSize)

proc overload*(directory: string = "", filename: string = ".env", bufferSize: int = 4096): void =
  ## Load environment variables from the given directory using the given filename. Existing environment variables will be overwritten.
  loadFromFile(directory, filename, true, bufferSize)

when isMainModule:
  var str = """
# comment!
HELLO
FOO=BAR

MEANING_OF_LIFE="42"
MULTI="""

  str.add('"')
  str.add('"')
  str.add('"')

  str.add("""
I
SPAN
SEVERAL
LINES""")

  str.add('"')
  str.add('"')
  str.add('"')

  str.add("\ntrailing=1")

  load(newStringStream(str))

  echo "HELLO = '", getEnv("HELLO"), "'"
  echo "FOO = '", getEnv("FOO"), "'"
  echo "MEANING_OF_LIFE = '", getEnv("MEANING_OF_LIFE"), "'"
  echo "MULTI = '", getEnv("MULTI"), "'"
  echo "trailing = '", getEnv("trailing"), "'"

  load(filename = ".env.example")

  echo "SIMPLE_VAL = '", getEnv("SIMPLE_VAL"), "'"
  echo "ANOTHER_SIMPLE_VAL = '", getEnv("ANOTHER_SIMPLE_VAL"), "'"
  echo "MULTILINE_VAL = '", getEnv("MULTILINE_VAL"), "'"