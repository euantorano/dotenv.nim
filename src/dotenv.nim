## Loads environment variables from `.env`.

import std/streams, std/strtabs, std/strscans, std/os

proc processEnvFile(stream: Stream, overwrite: bool): void =
  var variables = newStringTable()

  var 
    line: string = ""
    inMultiLine: bool = false
    multilineKey: string = ""
    multilineValueBuffer: string = ""
  while stream.readLine(line):
    if len(line) == 0:
      continue

    if line[0] == '#':
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
      var
        key: string
        value: string
      if scanf(line, "$w$.", key):
        # key, no value
        discard
      elif scanf(line, "$w=\"\"\"$*", key, value):
        # key, multiline string start
        inMultiLine = true
        multilineKey = key
        multilineValueBuffer = value
        continue
      elif scanf(line, "$w=\"$*\"", key, value):
        # key, quoted value
        discard
      elif scanf(line, "$w=$*", key, value):
        # key, unqouted value
        discard
      else:
        # TODO: error
        continue

      variables[key] = value

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

  echo "HELLO = ", getEnv("HELLO")
  echo "FOO = ", getEnv("FOO")
  echo "MEANING_OF_LIFE = ", getEnv("MEANING_OF_LIFE")
  echo "MULTI = ", getEnv("MULTI")
  echo "trailing = ", getEnv("trailing")