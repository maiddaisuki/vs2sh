# vs2sh.sh

Create startup file for sh-compatible shell to allow use of Visual Studio
command line tools.

## Script Dependencies

If any of the following tools is missing, the script will abort execution:

- mktemp
- iconv

The script is likely to fail if following tools are missing:

- **sed** and **grep** that support -E option and character classes
- **tr** that supports character classes (used if **cygpath** is missing)

If present, following tools will be used:

- cygpath
- dos2unix

If they are missing, they will be emulated with shell functions.

The script is designed to be able to run in the following unix-like
environments on Windows:

- [MinGW](https://osdn.net/projects/mingw/) (also known as MinGW.org)
- [Cygwin](https://www.cygwin.com/)
- [Msys2](https://www.msys2.org/)
- [Git for Windows](https://gitforwindows.org/)

The script has performance issues when run on Windows.
See **Performance issues on Windows** Section below.

The script should also be able to run under other operating system such as
GNU/Linux. The script was tested to run on GNU/Linux Debian (Bookworm).

## Usage

### Environment files

The script reads **environment files** in order to generate startup file.
The **environemt files** are text files containing output from **env**
without any options.
They contain newline-separated list of variables with their values in format:

    VARNAME=VALUE

The script requires two environment files:

- Development environment file.
- User environment file.

The _user environment file_ must contain output from **env** that is run from
normal **Command Prompt** or **PowerShell**.

The _development environment file_ must contain output from **env** that is run
from **Developer Command Prompt** or **Developer PowerShell**.

The **Developer Command Prompt** and **Developer PowerShell** are located
in Visual Studio's folder in the **Start Menu**. See
[Microsoft Docs](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line)
for details.

There are usually multiple versions of **Developer Command Propmpt** available:

- _ARCH_ Native Tools Command Prompt
- _HOST_\__TARGET_ Cross Tools Command Prompt

It is recommnded to use one of them to produce **development environment file**.

Please use the same shell to produce both environment files. If you used
**Developer Command Prompt** to produce _development environment file_,
then use normal **Command Prompt** to produce _user environment file_.

### Generating environment files

The **env** program must be used to generate **environment files**.
After you launch **[Developer] PowerShell/Command Prompt** invoke it with
absolute filename and redirect its output to file:

    Path/To/env >FILE

If you used Cygwin's **env** to genereate **environment files** run the script
from Cygwin's shell. It is required to correctly handle its **/cygpath** prefix
in PATH.

### Environment file encoding

By default, the script sets LC_ALL to C and will attempt to convert contents of
**environment files** to ASCII encoding.

The are many reasons why you may have non-ASCII characters in values of
environment variables. This will cause convertion to fail.

The --locale option is available to solve this issue:

- -l _LOCALE_
- --locale=_LOCALE_

The _LOCALE_ will be set as is to LC_ALL. Script will try to guess
correct encoding based on value of LC_ALL:

- C or POSIX - attempt to convert to ASCII
- _LANG_._ENCODING_ - will try to use _ENCODING_ as argument to iconv's -t option
- otherwise it falls back to UTF-8

The value **en_US.UTF-8** or similar should be save.

### Invokation

Simple invokation looks like this:

    ./vs2sh.sh -u USER_ENV_FILE -d DEV_ENV_FILE

You specify _user environment file_ with **-u** or **--user-env** option.  
You specify _development environment file_ with **-d** or **--dev-env** option.

Default name of output profile file is **vs.sh**.
You may specify another name with **-o** or **--output** option.
If value specified with -o or --output option contains directory parts,
they must exist.

You may list available options with:

    ./vs2sh.sh --help
    or
    ./vs2sh.sh -h

### Controlling profile generation

Following options affect how profile file is generated:

- \-\-[no-]cygpath - whether to use cygpath in generated profile.
  By default cygpath is used if it is found on the system.
  See **Cygpath and PATH** Section below.
- \-\-fast - do not perform variable substituion.
  See **Variable substituion** Section below.
- \-\-sdk=_VERSION_ - use specified _VERSION_ of Windows SDK.
- \-\-vctools=_VERSION_ - use specified _VERSION_ of Visual C tools.
- \-\-vcredist=_VERSION_ - use specified _VERSION_ of Visual C redist.

### Auxiliary output

Follwing options allow to generate auxiliary output:

- \-\-dump - produce auxiliary output in addition to normal output
- \-\-dump-only - produce auxiliary output only. Do not produce normal output
- \-\-dump-dir=_DIRNAME_ - specify directory where to store auxiliary output.
  The directory _DIRNAME_ must exist. By default they are written in the current
  directory.

The auxiliary output may be produces only if script is run on the same system
where **environment files** were generated.

When auxiliary output is requested, following additional files will be written:

- SDK.list - contains list of installed version of Windows SDK
- VCTOOLS.list - contains list of installed versions of Visual C tools
- VCREDIST.list - contains list of installed version of Visual C Redistributables

The **SDK.list**, **VCTOOLS.list** and **VCREDIST.list** contain valid values
for **--sdk**, **--vctools** and **--vcredist** options respectively.

## Using Generated Profile File

Users who know how their shell reads startup files may safely skip this section.

In the following example **~/** directory stands for User's home directory.

The simplest way to use it is to copy profile file to ~/ and add following line
to the end of your normal startup file (such as ~/.profile or ~/.bash_profile):

    . ~/vs.sh

This is not recommended since Visual Studio tools will be always present in your
PATH.

Another way to use it is Bash's --rcfile option.

Let's assume you have **~/.profile.d** directory where you store your profile files.
You copy **vs.sh** into **~/.profile.d** and create another file, let's call it
**vs-profile.sh**. In **vs-profile.sh** you write something like:

    . ~/.profile
    . ~/.profile.d/vs.sh

Then you invoke bash like this:

    bash --rcfile ~/.profile.d/vs-profile.sh

Ideally your Terminal Emulator should allow you to create a new profile where
you invoke bash like this.

With sh you may do it by setting _ENV_ varaible:

    env ENV=~/.profile.d/vs-profile.sh sh -i

## Features

The script tries to do more than just copy variables from
**development environment** to generated profile file.

### Variable Substitution

The script will attempt to write variables in specific order, so that value of
a variable that is defined earlier in the profile file may be referenced
in the value of a variable that is defined later in the profile file.

Example: There is variable named VSINSTALLDIR which contains name of the
directory where the Visual Studio is installed. Other variables have this value
as their prefix, instead of keeping it literally, we will replace it with a
reference to VSINSTALLDIR variable.

This operation takes some time and maybe disabled with **--fast** option. If you
use **--fast** option, the options **--sdk**, **--vctools** and **--vcredist**
will have no effect.

### Cygpath and PATH

This script may also perform variable substitution described above on
directories that are added to PATH. The **--[no-]cygpath** and **--fast** option
control this feature.

It is important to remember that PATH variable in mentioned unxi-like environments
for Windows must contain unix-style filenames. All other varaibles defined by
generated profile have windows-style filenames.

If we want to perform variable substituion on directories in PATH we will have
first to convert them to windows-style, then perform substitution, and finally
convert them back from windows-style to unix-style on the fly in profile file.

The **cygpath** allows to do it. Profiles generated this way may be used form
any unix-like environment that has **cygpath** which will handle proper
conversion from windows-style to unix-style filenames.

The **Cygwin** and **Git for Windows** have it by default. In **Msys2** you
may install it manually:

    pacman -Si cygpath

**MinGW** does not have cygpath.

Default behavior is to use **cygpath** in the profile file if it was found when
script was run.

- The **--cygpath** tells to always use it in generated profile.
- The **--no-cygpath** tells to never use it in the generated profile.

This allows you to generate profile that uses **cygpath** when the script is run
on another operating system that does not have **cygpath**.

The **--fast** options also affects this conversion. If **cygpath** is used while
**--fast** is specified, directories will not have variable references.

### Specifying Tools Version

By default **Developer Command Prompt/Powershell** will use latest version of
Visual C tools and Windows SDK that are installed.

You may tell them to work with specific versions. Please read
[Microsoft Docs](https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line)
to learn how to do it.

You may want to work with a different version of Visual C tools and/or
Windows SDK if you have them installed. To simplify it, the **--sdk**,
**--vctools** and **--vcredist** options are avaialble.

You have to specify valid values for generated profile to work properly.
You may request the script do dump additional output files with **--dump** or
**--dump-only**, which will contain valid values.

This approach should work fine for Windows 10/11 SDKs, but may not work with
SDKs for older version of Windows. If you need to use such SDK,
follow instructions at **Microsoft Docs** to setup
**Developer Command Prompt/PowerShell**, and then generate
_development environment file_ from it.

If profile generated with **--sdk**, **--vctools** and/or **--vcredist** options
fails to work, you will have to setup it following instructions at **Microsoft Docs**
and generate new _development environment file_ from it.

## Known Issues

### Performance issues on Winodws

The script takes much longer to execute on Windows compared to GNU/Linux.

On author's GNU/Linux Debian the script takes about 2 second to complete with
--cygpath option and without --fast. While with the same options,
it takes about 36 seconds to complete from **Git for Windows**'s bash.

If users have WSL installed on their Windows systems, it is recommended to run
the script from WSL environment. Note that in this case
the **environment files** should not be generated by Cygwin's **env**.

This may not be critical for a single run, but it may become annoying when you
need to generate several different profile files.

## License

The vs2sh.sh is licensed under terms of GNU General Public License Version 3.
See [LICENSE](LICENSE) for details.
