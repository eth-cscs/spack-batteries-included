package main

import (
    "debug/elf"
    "fmt"
    "log"
    "os"
    "os/exec"
    "path/filepath"
    "sort"
    "strings"
    "syscall"
)

func check(e error) {
    if e != nil {
        panic(e)
    }
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


func MakeThingsRelativeToRoot(root string, directories []string) {
    fileList := make([]string, 0)

    for _, walk_dir := range directories {
        e := filepath.Walk(walk_dir, func(path string, f os.FileInfo, err error) error {
            fileList = append(fileList, path)
            return err
        })
        check(e)
    }

    // We store the path of the first inode which is a hardlink
    // and then if we ever stumble upon the same inode again,
    // we delete it and replace it by a symlink
    inode_to_filename := make(map[uint64]string)

    all_dt_needed := make(map[string][]string)
    all_so_names := make(map[string]bool)

    for _, file := range fileList {
        // Get the current working directory
        current_file_dir := filepath.Dir(file)

        // Try to get some file details
        info, err := os.Lstat(file)
        check(err)

        // Get info about whether this is a hardlink (nlink > 0).
        nlink := uint64(0)
        ino := uint64(0)
        if sys := info.Sys(); sys != nil {
            if stat, ok := sys.(*syscall.Stat_t); ok {
                nlink = uint64(stat.Nlink)
                ino = uint64(stat.Ino)
            }
        }

        // If it is a hardlink, we will transform it into a symlink when we've
        // already seen its inode before. Then we continue with the next file.
        // If it's not seen before, we just store it, and rewrite rpaths and such.
        if nlink > 0 {
            if path, ok := inode_to_filename[ino]; ok {
                // replace it with a symlink to the parent
                relative_symlink, err := filepath.Rel(current_file_dir, path)
                check(err)
                log.Printf("Changing hardlink `%s` to symlink to `%s`\n", PrettyPath(root, file), relative_symlink)
                err = os.Remove(file)
                check(err)
                err = os.Symlink(relative_symlink, file)
                check(err)
                continue
            } else {
                // keep it and just store it
                inode_to_filename[ino] = file
            }
        }

        // Make symlinks relative
        if info.Mode()&os.ModeSymlink == os.ModeSymlink {
            // log.Printf("Checking symbolic link %s\n", PrettyPath(root, file))
            original_symlink, err := os.Readlink(file)
            check(err)

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
            }

            // Turn into relative path
            relative_symlink, err := filepath.Rel(current_file_dir, absolute_symlink)

            if relative_symlink != original_symlink {
                log.Printf("Rewriting symlink `%s` from `%s` to `%s`\n", PrettyPath(root, file), original_symlink, relative_symlink)
                err = os.Remove(file)
                check(err)
                err = os.Symlink(relative_symlink, file)
                check(err)
            }

            continue
        }

        // Check if this is an Elf file
        _elf, err := elf.Open(file)

        // Errors just means it's not an Elf file
        if err != nil { continue }

        if _elf.Type != elf.ET_DYN && _elf.Type != elf.ET_EXEC {
            log.Printf("Skipping %s (not dynamic lib or executable)\n", PrettyPath(root, file))
            continue
        }

        // collect DT_NEEDED
        dt_needed, err := _elf.DynString(elf.DT_NEEDED)
        check(err)
        for _, lib := range dt_needed {
            all_dt_needed[lib] = append(all_dt_needed[lib], file)
        }

        // collect SONAME
        dt_soname, err := _elf.DynString(elf.DT_SONAME)
        check(err)
        for _, soname := range dt_soname {
            all_so_names[soname] = true
        }

        // --- MAKE ELF FILES DT_RPATH AND DT_RUNPATH RELATIVE ---
        // log.Printf("Checking lib/executable %s\n", PrettyPath(root, file))

        // Get RPATHs and RUNPATHs
        rpath_strings, err := _elf.DynString(elf.DT_RPATH)
        check(err)
        runpath_strings, err := _elf.DynString(elf.DT_RUNPATH)
        check(err)

        // Keep track if we have to rewrite to rpaths
        // We always rewrite runpaths to rpaths
        changed := len(runpath_strings) > 0 && len(runpath_strings[0]) > 0

        old_rpaths := append(rpath_strings, runpath_strings...)

        var new_rpaths []string

        for _, section := range old_rpaths {
            rpaths := strings.Split(section, ":")
            for _, rpath := range rpaths {
                // Replace ${ORIGIN} and $ORIGIN with elf file directory
                full_rpath := strings.ReplaceAll(rpath, "${ORIGIN}", current_file_dir)
                full_rpath = strings.ReplaceAll(full_rpath, "$ORIGIN", current_file_dir)

                if !filepath.IsAbs(full_rpath) {
                    // Warn about relative rpaths...
                    log.Printf("\nWarning: %s has a relative rpath, skipping!\n - rpath: %s\n", PrettyPath(root, file), full_rpath)
                    changed = true
                    continue
                } else if !HasFilePathPrefix(full_rpath, root) {
                    // Warn about rpaths pointing out of the self-contained folder.
                    log.Printf("\nWarning: %s has an rpath pointing outside the root directory! Skipping\n - root: %s\n - rpath: %s\n", PrettyPath(root, file), root, full_rpath)
                    changed = true
                    continue
                }

                // Make rpath relative to elf directory
                elf_file_to_rpath, err := filepath.Rel(current_file_dir, full_rpath)
                check(err)

                // Prepend with $ORIGIN/relative/path/to/lib
                rewritten := "$ORIGIN/" + elf_file_to_rpath

                // Store the new rpath
                new_rpaths = append(new_rpaths, rewritten)

                // Check if it actually changed.
                if rewritten != rpath { changed = true }
            }
        }

        final_rpath := strings.Join(new_rpaths, ":")

        // Don't invoke patchelf unnecessarily
        if changed {
            set_rpath := exec.Command("patchelf", "--force-rpath", "--set-rpath", final_rpath, file)
            set_rpath.Stderr = os.Stderr
            err = set_rpath.Run()
            if err != nil { log.Printf("Issues rewriting the rpath") }
        }
    }

    fmt.Println("Linked system libraries found:")
    // Remove libs we ship from the list
    for so_name := range all_so_names {
        delete(all_dt_needed, so_name);
    }
    libs := make([]string, 0, len(all_dt_needed))
    for key := range all_dt_needed {
        libs = append(libs, key)
    }
    sort.Strings(libs)
    for _, lib := range libs {
        fmt.Printf("%s:\n", lib)

        for _, file := range all_dt_needed[lib] {
            rel_path, err := filepath.Rel(root, file)
            check(err)
            fmt.Printf(" - %s\n", rel_path)
        }
    }
}

func main() {
    if len(os.Args) < 2 {
        fmt.Printf("Usage: %s [root dir] [sub dir 1] [sub dir 2]...\n", os.Args[0])
        os.Exit(1)
        return
    }

    // First check if patchelf is avaiable...
    patchelf_path, err := exec.LookPath("patchelf")
    check(err)

    fmt.Printf("Found patchelf: %s\n", patchelf_path)
    patchelf_version := exec.Command("patchelf", "--version")
    patchelf_version.Stdout = os.Stdout
    err = patchelf_version.Run()
    check(err)

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

    fmt.Printf("Making `%s` a relocatable folder for all symlinks, executables and shared libs in:\n", root)
    for _, folder := range folders {
        fmt.Printf(" - %s\n", folder)
    }

    MakeThingsRelativeToRoot(root, folders)
}
