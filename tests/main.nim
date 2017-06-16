import dotenv, unittest, os

suite "dotenv tests":
  test "load simple environment variables from .env with full directory and file name":
    let env = initDotEnv("./", ".env.example")
    env.load()
    check getEnv("ANOTHER_SIMPLE_VAL") == "test"
    check getEnv("MULTILINE_VAL") == """This value

will span multiple lines, just like in Nim
"""

  test "load simple environment variables from a string":
    loadEnvFromString("""hello = world
    foo = bar
    """)
    check getEnv("hello") == "world"
    check getEnv("foo") == "bar"

  test "test load invalid .env file":
    expect DotEnvParseError:
      loadEnvFromString(r"inv~lid=world")

  test "test load invalid .env file 2":
    expect DotEnvParseError:
      loadEnvFromString(r"invalid!=world")

  test "test load .env file with exports":
    loadEnvFromString(r"""
    export exportedHello=world
    """)
    check getEnv("exportedHello") == "world"
