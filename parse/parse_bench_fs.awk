# gawk
#
# Available settings:
# -vno_fio=1
# -vno_dd=1
function parse_dd_speed(l)
{
    return gensub(/[^,]*,[^,]*, /, "", "g", l)
}
# @return last index in array
function parse_dd(mnt, lines)
{
    fallocate = 0
    for (i in lines) {
        l = lines[i]

        if (l ~ /Fio /) {
            break
        }
        delete lines[i]

        if (l ~ /Perform /) {
            prefix = gensub(/^Perform (.*) on .*$/, "\\1", "g", l)
            continue
        }
        if (l ~ /Preallocated /) {
            fallocate = 1
            continue
        }
        if (l ~ /records (in|out)/) {
            continue
        }
        speed = parse_dd_speed(l)
        printf("%s: %s%s %s\n", mnt, prefix, (fallocate ? " fallocate" : ""), speed)
    }

    return i
}
function parse_fio(mnt, lines)
{
    for (i in lines) {
        l = lines[i]

        if (l ~ /^f[0-9]+: \(g=[0-9]+\):/) {
            id   = gensub(/^f[0-9]+: \(g=([0-9]+)\): (.*)$/, "\\1", "g", l)
            info = gensub(/^f[0-9]+: \(g=([0-9]+)\): (.*)$/, "\\2", "g", l)
            groups[id] = info
        }
        if (l ~ /Run status group [0-9]+ \(all jobs\):/) {
            group = gensub(/^Run status group ([0-9]+) \(all jobs\):$/, "\\1", "g", l)
            continue
        }
        if (l ~ /(WRITE|READ): io/) {
            read = tolower(gensub(/^.*(WRITE|READ):.*$/, "\\1", "g", l))
            info = gensub(/^.*(WRITE|READ):\s*(.*)$/, "\\2", "g", l)

            split(info, parts, ", ")
            delete parts[1] # io

            for (p in parts) {
                speed = gensub(/^([a-z]*)=([0-9.]*)(.*)$/, "\\1 \\2 \\3", "g", parts[p])
                printf("%s: %s %s %s\n", mnt, groups[group], read, speed)
            }
        }
    }
}

{
    # XXX: fix this stuff for lvm!
    if ($0 ~ /No space left on device/) {
        next
    }
    if ($0 ~ /No such file or directory/) {
        next
    }

    if ($0 ~ /^Perform cached write on/) {
        mnt=substr($NF, 1, length($NF)-3)
    }
    lines[mnt][length(lines[mnt])] = $0
} END {
    for (mnt in lines) {
        if (!no_dd) {
            parse_dd(mnt, lines[mnt])
        }
        if (!no_fio) {
            parse_fio(mnt, lines[mnt])
        }
    }
}
