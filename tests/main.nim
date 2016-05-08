import dotenv, unittest, os

suite "dotenv tests":
  test "load simple environment variables from .env":
    let env = initDotEnv()
    env.load()
    check getEnv("hello") == "world"
