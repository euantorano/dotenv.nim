import dotenv, std/unittest, std/streams, std/os

suite "dotenv tests":
  test "simple unquoted":
    load(newStringStream("""hello=world
foo=bar
    """))
    check getEnv("hello") == "world"
    check getEnv("foo") == "bar"

  test "simple quoted":
    load(newStringStream("""hello=world
foo=\"bar\"
    """))
    check getEnv("hello") == "world"
    check getEnv("foo") == "bar"

  test "load does not overwrite":
    putEnv("overwrite_me", "0")
    load(newStringStream("overwrite_me=1"))

    check getEnv("overwrite_me") == "0"

  test "overload does overwrite":
    putEnv("overwrite_me", "0")
    overload(newStringStream("overwrite_me=1"))

    check getEnv("overwrite_me") == "1"

  test "unqouted directory path":
    load(newStringStream("""hello=world
FS_ROOT=/home/ajusa/Documents
    """))

    check getEnv("FS_ROOT") == "/home/ajusa/Documents"

  test "comments after quoted value":
    load(newStringStream("""foo=\"bar\" # this is a comment"""))
    check getEnv("foo") == "bar"

  test "comment line":
    load(newStringStream("""hello=world
# this is a comment
foo=\"bar\"
"""))
    check getEnv("hello") == "world"
    check getEnv("foo") == "bar"
