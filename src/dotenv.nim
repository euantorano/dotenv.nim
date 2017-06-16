## Loads environment variables from `.env`.

import os, streams, dotenv/private/envparser

type
  EnvVar = tuple[name: string, value: string]
  DotEnv* = object
    ## The main dotenv object, stores a reference to the `.env` file path.
    filePath: string
  DotEnvPathError* = object of Exception
    ## Error thrown when the given file or directory path doesn't exist.
  DotEnvReadError* = object of Exception
    ## Error thrown when reading from the `.env` file fails.
  DotEnvParseError* = object of Exception
    ## Error thrown if a parse error occurs while reading the `.env` file.

proc initDotEnv*(directory: string, fileName: string = ".env"): DotEnv {.raises: [DotEnvPathError, ref OSError], tags: [ReadDirEffect] .} =
  ## Initialise a `DotEnv` instance using the specified `.env` file.
  ## By default, it will look for a file `.env` in the given path, but this can be overriden.
  if not existsDir(directory):
    raise newException(DotEnvPathError, "Directory '" & directory & "' does not exist")

  # Check if the `directory` path is actually a file path. If so, use it.
  let fileInfo = getFileInfo(directory)
  if fileInfo.kind in {pcFile, pcLinkToFile}:
    return DotEnv(filePath: directory)

  var file = fileName
  if len(file) < 1:
    file = ".env"

  let path = joinPath(directory, file)

  if not existsFile(path):
    raise newException(DotEnvPathError, "Path '" & path & "' does not exist")

  result = DotEnv(filePath: path)

proc initDotEnv*(): DotEnv {.raises: [DotEnvPathError, ref OSError], tags: [ReadDirEffect].} =
  ## Initialise a `DotEnv` instance using the current working directory.
  let path = joinpath(getCurrentDir(), ".env")
  if not existsFile(path):
    raise newException(DotEnvPathError, "Path '" & path & "' does not exist")

  result = DotEnv(filePath: path)

iterator loadFromStream(s: Stream, filePath: string = ""): EnvVar {.raises: [DotEnvParseError, ref ValueError, Exception].} =
  ## Read all of the environment variables from the given stream.
  var parser: EnvParser
  envparser.open(parser, s, filePath)
  defer: close(parser)
  while true:
    var e = parser.next()
    case e.kind
    of EnvEventKind.Eof:
      break
    of EnvEventKind.KeyValuePair:
      yield (name: e.key, value: e.value)
    of EnvEventKind.Error:
      raise newException(DotEnvParseError, e.msg)

iterator loadFromFile(filePath: string): EnvVar {.tags: [ReadDirEffect, ReadIOEffect, RootEffect], raises: [DotEnvReadError, DotEnvParseError, ref ValueError, Exception].} =
  ## Load the environment variables from a file at the given `filePath`.
  let f = newFileStream(filePath, fmRead)

  if isNil(f):
    raise newException(DotEnvReadError, "Failed to read env file")

  for entry in loadFromStream(f, filePath):
    yield entry

iterator loadFromString(content: string): EnvVar {.tags: [ReadDirEffect, ReadIOEffect, RootEffect], raises: [DotEnvReadError, DotEnvParseError, ref ValueError, Exception].} =
  ## Load the environment variables from a given `content` string.
  let ss = newStringStream(content)

  if isNil(ss):
    raise newException(DotEnvReadError, "Failed to read env file")

  for entry in loadFromStream(ss):
    yield entry

proc load*(de: DotEnv) {.tags: [ReadDirEffect, ReadIOEffect, RootEffect, ReadEnvEffect, WriteEnvEffect], raises: [OSError, Exception].} =
  ## Load the environment variables from the .env file. Any existing environment variables will not be overwritten.
  for envVar in loadFromFile(de.filePath):
    if not existsEnv(envVar.name):
      putEnv(envVar.name, envVar.value)

proc overload*(de: DotEnv) {.tags: [ReadDirEffect, ReadIOEffect, RootEffect, ReadEnvEffect, WriteEnvEffect], raises: [OSError, Exception].} =
  ## Load the environment variables from the .env file. Any existing environment variables will be overwritten with new values from the file.
  for envVar in loadFromFile(de.filePath):
    putEnv(envVar.name, envVar.value)

proc loadEnvFromString*(content: string) {.tags: [ReadDirEffect, ReadIOEffect, RootEffect, ReadEnvEffect, WriteEnvEffect], raises: [OSError, Exception].} =
  ## Load the environment variables from the given `content` string. Any existing environment variables will not be overwritten.
  for envVar in loadFromString(content):
    if not existsEnv(envVar.name):
      putEnv(envVar.name, envVar.value)

proc overloadEnvFromString*(content: string) {.tags: [ReadDirEffect, ReadIOEffect, RootEffect, ReadEnvEffect, WriteEnvEffect], raises: [OSError, Exception].} =
  ## Load the environment variables from the given `content` string. Any existing environment variables will be overwritten with new values from the file.
  for envVar in loadFromString(content):
    putEnv(envVar.name, envVar.value)
