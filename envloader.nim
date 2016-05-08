# Loader responsible for loading variables from a .env file.

import envparser, streams, os

type
  EnvVar = tuple[name: string, value: string]
  EnvLoader* = ref EnvLoaderObj
  EnvLoaderObj = object
    ## Loader responsible for loading variables out of a file into a map of key => val
    filePath: string
  DotEnvReadError* = object of Exception

proc initEnvLoader*(path: string): EnvLoader =
  ## Create a new `EnvLoader` with the given path.
  result = EnvLoader(filePath: path)

iterator load*(el: EnvLoader): EnvVar {.tags: [ReadDirEffect, ReadIOEffect, RootEffect], raises: [OSError, Exception].} =
  let f = newFileStream(el.filePath, fmRead)

  if isNil(f):
    raise newException(DotEnvReadError, "Failed to read env file")

  var parser: EnvParser
  envparser.open(parser, f, el.filePath)
  while true:
    var e = parser.next()
    case e.kind
    of envEof:
      break
    of envKeyValuePair:
      yield (name: e.key, value: e.value)
    of envError:
      # TODO: Exception!
      echo(e.msg)
  close(parser)