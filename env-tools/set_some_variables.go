package main

import (
    "os/exec"
    "path/filepath"
    "io/ioutil"
    "bytes"
    "fmt"
    "log"
    "os"
    "strings"
)

func check(e error) {
    if e != nil {
        panic(e)
    }
}

func HasFilePathPrefix(s, prefix string) bool {
    sv := strings.ToUpper(filepath.VolumeName(s))
    pv := strings.ToUpper(filepath.VolumeName(prefix))
    s = s[len(sv):]
    prefix = prefix[len(pv):]
    switch {
    default:
        return false
    case sv != pv:
        return false
    case len(s) == len(prefix):
        return s == prefix
    case prefix == "":
        return true
    case len(s) > len(prefix):
        if prefix[len(prefix)-1] == filepath.Separator {
            return strings.HasPrefix(s, prefix)
        }
        return s[len(prefix)] == filepath.Separator && s[:len(prefix)] == prefix
    }
}


func main() {
    if len(os.Args) != 3 {
        fmt.Printf("Usage: %s [root dir] [path/to/perl]\n", os.Args[0])
        os.Exit(1)
        return
    }

    // Make input absolute
    root, err := filepath.Abs(os.Args[1])
    check(err)
    root = filepath.Clean(root)

    root_info, err := os.Stat(root)

    if err != nil || !root_info.IsDir() {
        log.Printf("%s is not a directory", root)
        os.Exit(1)
    }

    // Make sure that <root>/AppRun.in exists
    apprun_in_path := filepath.Join(root, "AppRun.in")
    _, err = os.Stat(apprun_in_path)

    if err != nil {
        log.Printf("Can't find AppRun.in in %s", apprun_in_path)
    }

    // Validate path to perl
    perl_path := os.Args[2]

    if !filepath.IsAbs(perl_path) {
        perl_path = filepath.Join(root, perl_path)
    }

    perl_path = filepath.Clean(perl_path)

    if !HasFilePathPrefix(perl_path, root) {
        log.Printf("%s not contained in root folder %s\n", perl_path, root)
        os.Exit(1)
        return
    }

    // Run qq(@INC) to get the include path of perl
    cmd := exec.Command(perl_path, "-e", "print qq(@INC)")
    var out bytes.Buffer
    cmd.Stdout = &out
    err = cmd.Run()
    check(err)

    // Parse the include paths
    paths := strings.Fields(out.String())
    PERL5LIB := ""
    for _, path := range paths {
        // make relative
        path = filepath.Clean(path)
        rel, err := filepath.Rel(root, path)
        check(err)
        PERL5LIB += filepath.Join("$HERE", rel) + ":"
    }

    // Open AppRun.in and replace {{PERL5PATH}} with the paths we got.
    read, err := ioutil.ReadFile(apprun_in_path)
    check(err)
    newContents := strings.ReplaceAll(string(read), "{{PERL5LIB}}", PERL5LIB)
    err = ioutil.WriteFile(filepath.Join(root, "AppRun"), []byte(newContents), 0755)
    check(err)
}
