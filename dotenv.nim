# Loads environment variables from `.env`.

import os, streams, envloader

type
  DotEnv* = ref DotEnvObj
  DotEnvObj* = object
    ## The main dotenv object, stores a reference to the `.env` file path.
    filePath: string
  DotEnvPathError* = object of Exception

proc initDotEnv*(directory: string, fileName: string = ".env"): DotEnv {.raises: [DotEnvPathError, ref OSError], tags: [ReadDirEffect] .} =
  ## Initialise a `DotEnv` instance using the specified `.env` file.
  ## By default, it will look for a file `.env` in the given path, but this can be overriden.
  if not existsDir(directory):
    raise newException(DotEnvPathError, "Directory '" & directory & "' does not exist")

  # Check if the `directory` path is actually a file path. Ff so, use it.
  let fileInfo = getFileInfo(directory)
  if fileInfo.kind == pcFile or fileInfo.kind == pcLinkToFile:
    return DotEnv(filePath: directory)

  var file = fileName
  if isNil(file) or file == "":
    file = ".env"

  let path = joinPath(directory, file)

  if not existsFile(path):
    raise newException(DotEnvPathError, "Path '" & path & "' does not exist")

  return DotEnv(filePath: path)

proc initDotEnv*(): DotEnv {.raises: [DotEnvPathError, ref OSError], tags: [ReadDirEffect].} =
  ## Initialise a `DotEnv` instance using the current working dorectory.
  let path = joinpath(getCurrentDir(), ".env")
  if not existsFile(path):
    raise newException(DotEnvPathError, "Path '" & path & "' does not exist")

  return DotEnv(filePath: path)

proc load*(de: DotEnv) {.tags: [ReadDirEffect, ReadIOEffect, RootEffect, ReadEnvEffect, WriteEnvEffect], raises: [OSError, Exception].} =
  ## Load the environment variables from the .env file. Any existing environment variables will not be overwritten.
  let loader = initEnvLoader(de.filePath)

  for envVar in loader.load():
    if not existsEnv(envVar.name):
      putEnv(envVar.name, envVar.value)

proc overload*(de: DotEnv) {.tags: [ReadDirEffect, ReadIOEffect, RootEffect, ReadEnvEffect, WriteEnvEffect], raises: [OSError, Exception].} =
  ## Load the environment variables from the .env file. Any existing environment variables will be overwritten with new values from the file.
  let loader = initEnvLoader(de.filePath)

  for envVar in loader.load():
    putEnv(envVar.name, envVar.value)
