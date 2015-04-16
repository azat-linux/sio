BEGIN {
    # XXX: yes I know about FPAT, but don't have time for begging
    #
    # FPAT = "^([^ ]*): (.+) ([^ ]+) ([^ ]+)$"
    # FPAT = "^([^ ]*)|.+)|([^ ]+)|([^ ]+)$"
} {
    cfg = gensub(/^([^ \t]+).*$/, "\\1", "g", $0)
    key = gensub(/^([^ \t]+)\t([^ \t]+):.*$/, "\\2", "g", $0)
    value = gensub(/^.* ([^ ]+) ([^ ]+)$/, "\\1 \\2", "g", $0) # <VAL> <SPEED>

    keyLen = length(key) + 3 + length(cfg) + 1
    type = substr($0, keyLen, length($0) - length(value) - keyLen)

    if (debug)
    {
        print "NF  = " NF
        print "cfg = " cfg
        print "key = " key
        print "typ = " type
        print "val = " value
    }

    keys[cfg][key][type] = value
    types[type] = 1
} END {
    # header
    printf("%s", "configuration")
    printf("\t%s", "device")
    for (t in types) {
        printf("\t%s", t)
    }
    printf("\n")

    # table
    for (c in keys) {
        for (k in keys[c]) {
            printf("%s", c)
            printf("\t%s", k)
            for (t in types) {
                value = keys[c][k][t]
                printf("\t%s", value)
            }
            printf("\n")
        }
    }
}
