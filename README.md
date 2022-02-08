# dotenv.nim

[dotenv](https://github.com/bkeepers/dotenv) implementation for Nim. Loads environment variables from `.env`

Storing [configuration in the environment](http://12factor.net/config) is one of the tenets of a [twelve-factor app](http://12factor.net). Anything that is likely to change between deployment environments–such as resource handles for databases or credentials for external services–should be extracted from the code into environment variables.

## Installation

`dotenv` can be installed using Nimble:

```
nimble install dotenv
```

Or add the following to your `.nimble` file:

```
# Dependencies

requires "dotenv >= 2.0.0"
```

## Usage

### Create a `.env` file

Create a `.env` file in the root of your project (or anywhere else - just be sure to specify the path when loading).

```
DB_HOST=localhost
DB_USER=root
DB_PASS=""
DB_NAME=test
```

Variables values are always strings, and can be either wrapped in quotes or left without.

Multiline strings can also be used using the `"""` syntax:

```
SOME_LONG_STRING="""This string is very long.

It will span multiple lines.
"""
```

You can also add comments, using the `#` symbol:

```
# Comments can fill a whole line
DB_NAME=test # Or they can follow an assignment
```

Variable values can reference other variables - either from the same `.env` file, or from the existing environment variables:

```
CONFIG_DIR=${HOME}/.config
CONFIG_FILE=${CONFIG_DIR}/config.json
```

* Variables are referenced either using `${VARIABLE}` or as simply `$VARIABLE`.
* Variables do not need to be defined before usage.
* Unknown variables are replaced with empty strings.

### Loading the `.env` file

You can load the `.env` file from the current working directory as follows:

```nim
import dotenv

load()
```

Or, you can specify the path to the directory and/or file:

```nim
import dotenv

load("/some/directory/path", "custom_file_name.env")

# You can now access the variables using os.getEnv()
```

By default, `dotenv` does not overwrite existing environment variables, though this can be done using `overload` rather than `load`:

```nim
import dotenv

overload()

# You can now access the variables using os.getEnv()
```

### Loading from a string

You can also load environment variables directly from a string using `std/streams`:

```nim
import dotenv, std/streams

load(newStringStream("""hello = world
foo = bar
"""))

assert getEnv("foo") == "bar"
```
