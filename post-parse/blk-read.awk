BEGIN {
    OFS="\t"
    FS="\t"
}
{
    if (FNR == 1) {
        for (i = 1; i <= NF; ++i) {
            if ($i == "-B32M-C100 buffered disk reads" ||
                $i == "-B32K-C10000 cached reads") {
                keys[i] = 1
            }
        }
    }
    printf("%s:%s\t", $1, $2)
    for (k in keys) {
        printf("%s\t", $k)
    }
    printf("\n")
}
