#!/usr/bin/awk -f

function parse_size(str)
{
    k = 0
    split("B KB MB GB", types, " ")
    for (t in types) {
        if (str ~ "^[0-9.]+[ ]*" types[t] "/(s|sec)[ ]*$") {
            k = t
        }
    }
    return sprintf("%.f", int(str) * (k ? (1024 ^ (k - 1)) : 1))
}
BEGIN {
    IGNORECASE=1

    if (testing) {
        print parse_size("1B/s")
        print parse_size("1KB/s")
        print parse_size("1MB/s")
        print parse_size("1 MB/s")
        print parse_size("1 MB/sec")
        print parse_size("1GB/s")
        print parse_size("1 GB/s")
        print parse_size("2GB/s")
    } else if (str) {
        print parse_size(str)
    }
} {
    for (i = 1; i <= NF-1; ++i) {
        printf("%s%s", $i, OFS)
    }
    print parse_size($NF)
}
