package main

import (
    "fmt"
    "os"
    "io/ioutil"
    "path/filepath"
)

func check(e error) {
    if e != nil {
        panic(e)
    }
}

func main() {
    // `file` is not relocatable, but it's also not always possible to force
    // libtool to use our version; so instead we wrap `file` in a shell script...
    
    if len(os.Args) < 2 {
        fmt.Printf("Usage: %s view/bin/file\n", os.Args[0])
        os.Exit(1)
        return
    }

    // Make input absolute
    file, err := filepath.Abs(os.Args[1])
    check(err)
    file = filepath.Clean(file)

    info, err := os.Lstat(file)
    check(err)

    if info.Mode()&os.ModeSymlink != os.ModeSymlink {
        fmt.Printf("%s is not a symlink; skipping\n", file)
        os.Exit(0)
    }

    points_to, err := os.Readlink(file)
    check(err)
    contents := `#!/bin/sh
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export MAGIC="$HERE/../share/misc/magic.mgc"
${HERE}/` + points_to + ` "$@"
`
    // remove it
    err = os.Remove(file)
    check(err)

    // replace with the shell script
    err = ioutil.WriteFile(file, []byte(contents), 0777)
    check(err)
}
