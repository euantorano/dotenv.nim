# Package

version       = "1.1.0"
author        = "Euan T"
description   = "dotenv implementation for Nim. Loads environment variables from `.env`"
license       = "BSD3"

srcDir = "src"

# Dependencies

requires "nim >= 0.16.0"

task test, "Run tests":
  exec "nim c -r tests/main.nim"

task docs, "Build documentation":
  exec "nim doc --index:on -o:docs/dotenv.html src/dotenv.nim"
