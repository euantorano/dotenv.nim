import dotenv, std/unittest, std/streams, std/os

suite "dotenv tests":
  test "simple unquoted":
    load(newStringStream("""hello1=world
foo1=bar
    """))

    check getEnv("hello1") == "world"
    check getEnv("foo1") == "bar"

  test "simple quoted":
    load(newStringStream("foo2=\"bar\""))

    check getEnv("foo2") == "bar"

  test "load does not overwrite":
    putEnv("overwrite_me", "0")
    load(newStringStream("overwrite_me=1"))

    check getEnv("overwrite_me") == "0"

  test "overload does overwrite":
    putEnv("overwrite_me", "0")
    overload(newStringStream("overwrite_me=1"))

    check getEnv("overwrite_me") == "1"

  test "unqouted directory path":
    load(newStringStream("FS_ROOT3=/home/ajusa/Documents"))

    check getEnv("FS_ROOT3") == "/home/ajusa/Documents"

  test "comments after quoted value":
    load(newStringStream("""foo4="bar" # this is a comment"""))

    check getEnv("foo4") == "bar"

  test "comment line":
    load(newStringStream("""hello5=world
# this is a comment
foo5="bar"
"""))

    check getEnv("hello5") == "world"
    check getEnv("foo5") == "bar"

  test "load from file":
    # NOTE: This expects that the tests are ran from the root, using `nimble test`    
    load("./", ".env.example")

    check getEnv("SIMPLE_VAL") == "test"
    check getEnv("ANOTHER_SIMPLE_VAL") == "test"
    check getEnv("MULTILINE_VAL") == "This value\n\nwill span multiple lines, just like in Nim\n"

  test "syntax error":
    expect(ParseError):
      load(newStringStream("""hello6=world
$$$"""))

  test "export keyword":
    var str = """export hello7=world
export foo7="bar"
export multiline7="""

    str.add('"')
    str.add('"')
    str.add('"')

    str.add("""this
is a multiline""")

    str.add('"')
    str.add('"')
    str.add('"')

    load(newStringStream(str))

    check getEnv("hello7") == "world"
    check getEnv("foo7") == "bar"
    check getEnv("multiline7") == "this\nis a multiline"

  test "variable substitution":
    load(newStringStream("""foo8=bar
baz8=foo ${foo8} $foo8
    """))

    check getEnv("baz8") == "foo bar bar"

  test "variable substitution without set variable should insert empty":
    overload(newStringStream("""foo9=bar
baz9=foo ${foo9} ${bar}
    """))

    check getEnv("baz9") == "foo bar "

  test "variable substitution with environment variable":
    load(newStringStream("dir10=${HOME}/foo"))

    check getEnv("dir10") == getEnv("HOME") & "/foo"