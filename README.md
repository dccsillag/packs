# packs

`packs` is a tool for synchronizing packages across machines, where you may or may not have root access.
It is written in POSIX shell, and has no dependencies (though you need `sudo` or `doas` if you plan on running something that requires root access).

## Overview

### What does it do? / How do I specify packages?

You should have something with the following structure at your `~/.local/share/packs/` (this location can be customized through the `PACKS_ROOT` environment variable):

```
/home/daniel/.local/share/packs/
└── packages/
   ├── my_package
   └── another_package
   ...
   └── yet_another_package
```

And the contents of files such as `my_package` are shell scripts that define specific functions, such as:

```
install_ubuntu() {
  "$SUDO" apt install my_package
}

install_conda() {
  conda install -c conda-forge my_package
}

install_manual() {
  curl -o ~/.local/bin/my_package_bin https://example.com/my_package
}
```

**Note:** If you use Vim, you'll probably want to add `# vim: ft=sh` either at the beginning or at the end of the file.

Here is a list of the functions that `packs` knows how to use in these package scripts:

| Name of the function | Corresponds to which install method                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------------------ |
| `install_ubuntu`     | Installs a package for an Ubuntu system; root access is assumed to be required.                              |
| `install_manjaro`    | Installs a package for a Manjaro system; root access is assumed to be required.                              |
| `install_nix`        | Installs a package using Nix.                                                                                |
| `install_guix`       | Installs a package using GNU Guix.                                                                           |
| `install_conda`      | Installs a package using Anaconda, in an isolated environment called `packs`.                                |
| `install_manual`     | Installs a package using only shell commands. This is used in the case that no package manager is available. |

More coming soon!

### Okay, I've specified some packages. How do I install them?

Just run the `packs.sh` script.

```sh
$ ./packs.sh
```

If you want, you can install it and simply run `packs` instead. See [Installation](#installation).

```sh
$ packs
```

## Installation

There is [an `install.sh` script](/install.sh). So, just run

```sh
./install.sh
```

Or, alternatively, if you don't want to have to clone this repository beforehand:

```
# Note that the following works without root access.
curl -o ~/.local/bin/packs https://raw.githubusercontent.com/dccsillag/packs/master/packs.sh
chmod +x ~/.local/bin/packs
```
