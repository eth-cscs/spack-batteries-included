package main

import (
    "fmt"
    "os"
    "path/filepath"
    "os/exec"
    "syscall"
)

func main() {
    ex, err := os.Executable()
    if err != nil { panic(err) }
    ex, err = filepath.EvalSymlinks(ex)
    if err != nil { panic(err) }
    cwd := filepath.Dir(ex)

    // Set up some env variables
    os.Unsetenv("SPACK_LD_LIBRARY_PATH")

    if _, isset := os.LookupEnv("SSL_CERT_DIR"); !isset {
        os.Setenv("SSL_CER_DIR", "/etc/ssl/certs:/etc/pki/tls/certs:/usr/share/ssl/certs:/usr/local/share/certs:/usr/local/etc/ssl")
    }

    os.Setenv("PATH", fmt.Sprintf("%s/view/bin/:%s/sbin/:%s/spack/bin:%s", cwd, cwd, cwd, os.Getenv("PATH")))
    os.Setenv("LD_LIBRARY_PATH", fmt.Sprintf("%s/view/lib/:%s/view/lib64/:%s", cwd, cwd, os.Getenv("LD_LIBRARY_PATH")))
    os.Setenv("PYTHONPATH", fmt.Sprintf("%s/view/lib/python3.8/site-packages:%s", cwd, os.Getenv("PYTHONPATH")))
    os.Setenv("SPACK_ROOT", fmt.Sprintf("%s/spack", cwd))
    os.Setenv("GIT_EXEC_PATH", fmt.Sprintf("%s/view/libexec/git-core", cwd))
    os.Setenv("MAGIC", fmt.Sprintf("%s/view/share/misc/magic.mgc", cwd))

    // Collec the arguments to be passed to python
    args := []string{
        fmt.Sprintf("%s/spack/bin/spack", cwd),
    }

    args = append(args, os.Args[1:]...)

    // Now execute the command.
    cmd := exec.Command(fmt.Sprintf("%s/view/bin/python3", cwd), args...)
    cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr

    if err := cmd.Start(); err != nil {
        os.Exit(1)
    }

    if err := cmd.Wait(); err != nil {
        if exiterr, ok := err.(*exec.ExitError); ok {
            if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
                os.Exit(status.ExitStatus())
            }
        } else {
            os.Exit(1)
        }
    }
}
