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

  test "load from file":
    # NOTE: This expects that the tests are ran from the root, using `nimble test`    
    load("./", ".env.example")

    check getEnv("SIMPLE_VAL") == "test"
    check getEnv("ANOTHER_SIMPLE_VAL") == "test"
    check getEnv("MULTILINE_VAL") == "This value\n\nwill span multiple lines, just like in Nim\n"

  test "syntax error":
    expect(ParseError):
      load(newStringStream("""hello=world
$$$"""))

  test "export keyword":
    var str = """export hello=world
export foo=\"bar\"
export multiline="""

    str.add('"')
    str.add('"')
    str.add('"')

    str.add("""this
is a multiline""")

    str.add('"')
    str.add('"')
    str.add('"')

    load(newStringStream(str))

    check getEnv("hello") == "world"
    check getEnv("foo") == "bar"
    check getEnv("multiline") == "this\nis a multiline"