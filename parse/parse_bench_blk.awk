# gawk
{
    # XXX: fix lvm stuff
    if ($0 ~ /No such file or directory/) {
        next
    }

    if ($0 ~ /dev/) {
        blk = gensub(/(.*):/, "\\1", "g", $0)
    } else if (NF > 1) {
        if ($0 ~ /cached/) {
            type = "cached reads"
        } else {
            type = "buffered disk reads"
        }
        printf("%s: %s %s %s %s\n", blk, prefix, type, $(NF-1), $NF)
    }
}

