import dotenv, unittest, os

suite "dotenv tests":
  test "load simple environment variables from .env":
    let env = initDotEnv()
    env.load()
    check getEnv("hello") == "world"

  test "load simple environment variables from a string":
    loadEnvFromString("""hello = world
    foo = bar
    """)
    check getEnv("hello") == "world"
    check getEnv("foo") == "bar"

