# vs2sh.sh

The `vs2sh.sh` is a shell script used to create a simple shell script which
sets environment variables required to use Visual Studio command-line tools
such as `cl.exe` and `link.exe`.

The puropse of this script is to remove burden of setting variables such as
`PATH`, `INCLUDE` and `LIB` from the user.

By default, `vs2sh.sh` will generate script named `vs.sh` which you can source
from shell to setup the environment.

```shell
. vs.sh
```

The primary intended use of the resulting environment is to allow use
Visual Studio command-line tools with `GNU Autotools` (`Autoconf`, `Automake`
and `Libtool`).

```shell
some/src/dir/configure \
  CC='cl.exe -nologo' \
  CFLAGS='-MD ...' \
  CXX='cl.exe -nologo' \
  CXXFLAGS='-MD ...' \
  LD='link.exe -nologo' \
  AR='lib.exe' \
  RANLIB=: \
  NM='dumpbin.exe -nologo -symbols'
```

Usually, you would use one of the following environments:

- [MinGW](https://osdn.net/projects/mingw/)
- [Cygwin](https://www.cygwin.com/)
- [Msys2](https://www.msys2.org/)

The `vs2sh.sh` may also be run from [Git for Windows](https://gitforwindows.org/).  
Keep in mind that `Git fo Windows` does not provide `make` utility
required to use `GNU Autotools`.

It may also be used with `CMake` and `Meson` build system installed from `Msys2`.

## Invokation

This section describes how to use `vs2sh.sh`.

### Environment Files

Before you can run `vs2sh.sh` you need to generate input files to which we will
refer as **environment files**.

Those **environment files** are plain text files containing output from `env`
when it is run without any options.  
The `env` utility is part of `GNU coreutils` which is installed with
environments listed above.

You need to generate two of those:

- **user environment file**
- **development environment file**

The **user environment file** is generated from either `Command Prompt` or
`PowerShell`.

The **development environment file** is generated from either
`Developer Command Prompt` or `Developer PowerShell`.

The `Developer Command Prompt` and `Developer PowerShell` are located in
**Start Menu** entry of your Visual Studio installation.

### Running vs2sh.sh

Simple invokation looks like

```shell
./vs2sh.sh -u USER-ENV-FILE -d DEV-ENV-FILE
```

Available options may be listed with

```shell
./vs2sh.sh --help
# or
./vs2sh.sh -h
```

The `vs2sh.sh` supports following options:

| Long Option           | Short Option | Description                                                 |
| :-------------------- | :----------- | ----------------------------------------------------------- |
| --user-env=`FILENAME` | -u           | Specify **user environment file**                           |
| --dev-env=`FILENAME`  | -d           | Specify **development environment file**                    |
| --output=`FILENAME`   | -o           | Specify output file (default is `vs.sh`)                    |
| --locale=`LOCALE`     | -l           | Specify locale to use (default is `C`)                      |
| --fast                | -f           | Skip [Variable Substitution](#variable-substitution)        |
| --[no-]cygpath        |              | Whether to [use cygpath](#using-cygpath) in the output file |

Following options are described in [Tools and SDK Version](#tools-and-sdk-version):

- --sdk=VERSION
- --vctools=VERSION
- --vcredist=VERSION

Following options are described in [Auxiliary Output](#auxiliary-output):

- --dump
- --dump-only
- --dump-dir=DIRNAME

## Features

This section describes features supported by `vs2sh.sh`.

### Using `cygpath`

By default, `vs2sh.sh` will use `cygpath` in generate output file if it is
installed when the script is run. This allows generated output file to be usable
from both `Cygwin` and `Msys2`.

The `cygpath` is installed by default with `Cygwin` and `Git for Windows`.
In `Msys2` it may be installed manually:

```shell
pacman -S cygpath
```

The `--cygpath` option forces use of `cygpath` in the generated file.  
The `--no-cygpath` option prohibits use of `cygpath` in generated the file.

### Variable Substitution

The `vs2sh.sh` tries to generate its output in a way that variables set earlier
may be used as part of variables set later.

This, for example, allows you modify variables like `VCToolsVersion` and
`WindowsSDKVersion` to change version of Visual C tools and Windows SDK to use.

However, since this process is time-consuming, you may disable this behavior
with `--fast` and `-f` options.

### Tools and SDK Version

By default, both `Developer Command Prompt` and `Developer PowerShell` use
latest installed versions of Visual C Tools and Windows SDK.

Following options tell `vs2sh.sh` to try generate output file to use different
versions:

| Option               | Description                                          |
| :------------------- | ---------------------------------------------------- |
| --sdk=`VERSION`      | Use specified `VERSION` of Windows SDK               |
| --vctools=`VERSION`  | Use specified `VERSION` of Visual C Tools            |
| --vcredist=`VERSION` | Use specified `VERSION` of Visual C Redistributables |

`NOTE:` `--vcredist` only affects value of `VCToolsRedistDir`.  
I am unsure whether it has any effect outside of Visual Studio.

The `vs2sh.sh` does it by manipulating variables in the generated output file.
This may not work for older version of Visual Studio.

You may set which versions of Windows SDK and Visual C Tools must be used when
starting `Developer PowerShell/Command Prompt`. Please refer to
[Microsoft Docs](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line)
for details.

### Auxiliary Output

The `vs2sh.sh` may also produce list of installed versions of `Windows SDKs`,
`Visual C Tools` and `Visual C Redistributables`.

| Option               | Description                                           |
| :------------------- | :---------------------------------------------------- |
| --dump               | Produce auxiliary output in addition to normal output |
| --dump-only          | Produce auxiliary output only                         |
| --dump-dir=`DIRNAME` | Specify directory where to write auxiliary output     |

Using either `--dump` or `--dump-only` will result in three extra files:

- `SKD.list`: list of installed Windows SDKs
- `VCTOOLS.list`: list of installed Visual C Tools
- `VCREDIST.list`: list of installed Visual C Redistributables

`NOTE:` it is very likely that `VCTOOLS.list` and `VCREDIST.list` will contain
the same values.

These files are written to the current directory by default. You may specify
different directory with `--dump-dir`, which must exist.

This feature is mostly useful to get list of valid values for `--sdk`,
`--vctools` and `--vcredist` options.

## License

The `vs2sh.sh` is licensed under terms of GNU General Public License Version 3.  
See [LICENSE](LICENSE) for details.
