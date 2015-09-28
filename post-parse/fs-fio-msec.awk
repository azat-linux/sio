BEGIN {
    OFS="\t"
    FS="\t"
}
$0 ~ /configuration|\/work/ {
    if (FNR == 1) {
        for (i = 1; i <= NF; ++i) {
            if ($i ~ /t$/) {
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
