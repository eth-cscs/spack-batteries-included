package main

import (
    "fmt"
    "os"
    "io/ioutil"
    "path"
    "path/filepath"
)

func check(e error) {
    if e != nil {
        panic(e)
    }
}

func file_executable_wrapper(view_dir string, exe string) {
    file := path.Join(view_dir, exe)
    info, err := os.Lstat(file)
    check(err)

    if info.Mode()&os.ModeSymlink != os.ModeSymlink {
        fmt.Printf("  %s is not a symlink; skipping\n", exe)
        return
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

func main() {
    // `file` is not relocatable, but it's also not always possible to force
    // libtool to use our version; so instead we wrap `file` in a shell script...
    
    if len(os.Args) < 2 {
        fmt.Printf("Usage: %s view/bin\n", os.Args[0])
        os.Exit(1)
        return
    }

    // Make input absolute
    view, err := filepath.Abs(os.Args[1])
    check(err)
    view = filepath.Clean(view)

    // Make sure we have a directory
    info, err := os.Lstat(view)
    check(err)

    if !info.IsDir() { panic(fmt.Sprintf("%s is not a directory", view)) }

    exes := []string{
        "file", 
        "gendiff",
        "rpm",
        "rpm2archive",
        "rpm2cpio",
        "rpmbuild",
        "rpmdb",
        "rpmgraph",
        "rpmkeys",
        "rpmquery",
        "rpmsign",
        "rpmspec",
        "rpmverify",
    }
    for _, exe := range exes {
        fmt.Printf("Making sure %s has a file wrapper\n", exe)
        file_executable_wrapper(view, exe)
    }
}
