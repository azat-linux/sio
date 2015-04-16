# Merge vals for devs of similar configuration in parallel runs
function parallel_avg(set, prefix)
{
    for (c in set) {
        total = 0
        i = 0
        for (v in set[c]) {
            ++i
            total += v
        }
        avg = total / i
        print c prefix, int(avg)
    }
}

{
    cfg = $1
    dev = $2
    val = $3

    if (dev ~ /^parallel/) {
        if (dev ~ /work/) {
            works[cfg][val] = 1;
        } else {
            devs[cfg][val] = 1;
        }
    } else {
        print dev, val
    }
} END {
    parallel_avg(works, "_works")
    parallel_avg(devs, "_devs")
}
