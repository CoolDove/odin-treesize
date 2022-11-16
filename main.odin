package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:unicode/utf8"

root : string;

TreeInfo :: struct {
    path : string,
    size : i64
}

tree_infos : #soa[dynamic]TreeInfo;

main :: proc () {
    if len(os.args) > 1 {
        dir := os.args[1];
        if os.is_dir(dir) {
            root = dir;
        } else {
            fmt.printf("Invalid directory: %s\n", dir);
            return;
        }
    } else {
        root = os.get_current_directory();
    }

    {
        root_handle, _ := os.open(root);
        root_info, _ := os.fstat(root_handle);
        root = root_info.fullpath

        os.close(root_handle);
    }


    tree_size(root, 0)

    fmt.println("");
    fmt.printf(">>>>>>>>>>>>>\n");
    fmt.printf(">>>>TreeSize: %s\n", root);
    trim_prefix();
    output();
}

tree_size :: proc(path: string, ite: int) -> i64 {
    handle, open_err := os.open(path);
    defer os.close(handle);
    // assert(open_err == 0, fmt.tprintf("Failed to open dir: %s.\n", path));

    if open_err != 0 {
        fmt.printf("Failed to open: %s.\n", path);
        return 0;
    }

    info, stat_err := os.fstat(handle);
    assert(stat_err == 0, fmt.tprintf("Failed to get info: %s.\n", path));

    size : i64;
    if !info.is_dir {
        size = info.size;
    } else {
        infos, err := os.read_dir(handle, 0);
        assert(err == 0, fmt.tprintf("Failed to read dir: %s.\n", path));

        for info in infos {
            size += tree_size(info.fullpath, ite + 1);
        }
    }

    if ite < 2 {
        append_soa(&tree_infos, TreeInfo{info.fullpath, size});
    }

    if ite < 3 && info.is_dir {
        fmt.printf("%s: \t\t\t%iBytes\n", info.fullpath, size);
    }

    return size;
}

trim_prefix :: proc() {
    for i in &tree_infos {
        i.path = strings.trim_prefix(i.path, root);
    }
}

output :: proc() {
    max_length_of_path := 0;
    if len(tree_infos) == 0 {
        fmt.println("Nothing here...");
        return;
    }
    root_size := tree_infos[len(tree_infos) - 1].size;

    for i in tree_infos {
        length := len(i.path);
        if length > max_length_of_path {
            max_length_of_path = length;
        }
    }

    for i in tree_infos {
        using i;
        sb := strings.builder_make(context.temp_allocator);
        spaces := max_length_of_path + 4 - len(path);
        for i in 0..<spaces {strings.write_rune(&sb, ' ');}
        spacing_string := strings.to_string(sb);
        
        fmt.printf("%s: %s%s\t%s\n", path, spacing_string, format_size(size, context.temp_allocator), format_percent(size, root_size));
    }
}

percentage :: proc(child: i64, parent: i64) -> f64 {
    return cast(f64)child/cast(f64)parent;
}
format_percent :: proc(child: i64, parent: i64, allocator:= context.allocator) -> string {
    context.allocator = allocator;
    percent := percentage(child, parent) * 100.0;
    return fmt.aprintf("%.2f%%", percent);
}

format_size :: proc(size: i64, allocator:= context.allocator) -> string {
    context.allocator = allocator;
    kb := cast(f64)(size % 1024.0)/1024.0 + cast(f64)(size/1024.0);
    mb := kb / 1024.0;
    gb := mb / 1024.0;

    value : f64;
    unit  : string;

    if kb < 1.0 {
        value = f64(size);
        unit = "Bytes";
    } else if kb < 1024.0 {
        value = kb;
        unit = "KB";
    } else if mb < 1024.0 {
        value = mb;
        unit = "MB";
    } else {
        value = gb;
        unit = "GB";
    }
    
    return fmt.aprintf("% 8.3f %s", value, unit);
}
