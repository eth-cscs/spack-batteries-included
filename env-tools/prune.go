package main

import (
    "fmt"
    "io"
    "log"
    "os"
    "path/filepath"
    "strings"
)

func check(e error) {
    if e != nil {
        panic(e)
    }
}

func ioReader(file string) io.ReaderAt {
    r, err := os.Open(file)
    check(err)
    return r
}



// HasFilePathPrefix reports whether the filesystem path s
// begins with the elements in prefix.
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

func PrettyPath(root string, path string) string {
    rel, err := filepath.Rel(root, path)
    check(err)
    return rel
}


func Prune(root string, directories []string) {
    fileList := make([]string, 0)

    for _, walk_dir := range directories {
        e := filepath.Walk(walk_dir, func(path string, f os.FileInfo, err error) error {
            fileList = append(fileList, path)
            return err
        })
        check(e)
    }

    for _, file := range fileList {
        // Get the current working directory
        current_file_dir := filepath.Dir(file)

        // Try to get some file details
        info, err := os.Lstat(file)
        check(err)

        // Make symlinks relative
        if info.Mode()&os.ModeSymlink == os.ModeSymlink {
            // log.Printf("Checking symbolic link %s\n", PrettyPath(root, file))
            original_symlink, err := os.Readlink(file)

            if err == nil {
                // Make absolute just in case...
                var absolute_symlink string
                if !filepath.IsAbs(original_symlink) {
                    absolute_symlink = filepath.Join(current_file_dir, original_symlink)
                } else {
                    absolute_symlink = original_symlink
                }

                absolute_symlink = filepath.Clean(absolute_symlink)

                // Check if it points outside our root dir or not
                if !HasFilePathPrefix(absolute_symlink, root) {
                    log.Printf("\nWarning: %s is a symlink pointing outside the root directory!\n - root: %s\n - link: %s\n", PrettyPath(root, file), root, original_symlink)
                } else {
                    // Remove the thing it points to
                    os.RemoveAll(absolute_symlink)
                }
            }
        }

        // If it is a folder, remove it at the end
        if info.IsDir() {
            defer os.RemoveAll(file)
        } else {
            os.Remove(file)
        }
    }
}

func main() {
    if len(os.Args) < 2 {
        fmt.Printf("Usage: %s [root dir] [sub dir 1] [sub dir 2]...\n", os.Args[0])
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

    // If more args are passed, consider those paths
    folders := []string{root}

    if len(os.Args) > 2 {
        folders = os.Args[2:]
    }

    for idx, folder := range folders {

        // Make relative
        if !filepath.IsAbs(folder) {
            folder = filepath.Join(root, folder)
        }

        folder = filepath.Clean(folder)

        // Check if things are included in one another
        if !HasFilePathPrefix(folder, root) {
            log.Printf("%s not contained in root folder %s\n", folder, root)
            os.Exit(1)
            return
        }

        folder_info, err := os.Stat(folder)

        if err != nil || !folder_info.IsDir() {
            log.Printf("%s is not a directory", folder)
            os.Exit(1)
        }

        folders[idx] = folder
    }

    fmt.Printf("Removing the following from `%s` including what their symlinks point to:", root)
    for _, folder := range folders {
        fmt.Printf(" - %s\n", folder)
    }

    Prune(root, folders)
}
