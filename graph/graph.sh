#!/usr/bin/env bash

# Use this only for similar configuraitons.
#
# Example of similar configurations:
# - lvm_ext4_works6
# - lvm_tux3_works6
# - lvm_ext4_works4
# - lvm_tux3_works4
#
# - md2_ext4
# - md2_tux3
# - md3_ext4
# - md3_tux3
# - md4_ext4
# - md4_tux3

set -e

self="$(readlink -f $(dirname $0))"
plotsRoot="$self/plots"
types=(
    blk_read_cached
    blk_read_buffered
    fs_fio_rand_msec
    fs_fio_msec
    fs_fio_rand_read
    fs_fio_rand_write
    fs_fio_falloc
    fs_fio_read
    fs_fio_write
    fs_write_read
    fs_cached_write
)
# available: x11 qt png dumb
format=svg
resulution=$((1920*1)),$((1080*1))

rm -fr "$plotsRoot"
mkdir -p "$plotsRoot"
cd "$plotsRoot"

# XXX: generate this!
cols_blk_read_cached=(
    "-B32K-C10000 cached reads"
    "-B32M-C100 cached reads"
)
cols_blk_read_buffered=(
    "-B32K-C10000 buffered disk reads"
    "-B32M-C100 buffered disk reads"
)
cols_fs_fio_rand_msec=(
    "rw=randread, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 read maxt"
    "rw=randread, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 read mint"
    "rw=randread, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 read maxt"
    "rw=randread, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 read mint"
    "rw=randwrite, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 write maxt"
    "rw=randwrite, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 write mint"
    "rw=randwrite, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 write maxt"
    "rw=randwrite, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 write mint"
)
cols_fs_fio_msec=(
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=falloc, iodepth=1 read maxt"
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=falloc, iodepth=1 read mint"
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 read maxt"
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 read mint"
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 read maxt"
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 read mint"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=falloc, iodepth=1 write maxt"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=falloc, iodepth=1 write mint"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 write maxt"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 write mint"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 write maxt"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 write mint"
)
cols_fs_fio_rand_read=(
    "rw=randread, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 read aggrb"
    "rw=randread, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 read aggrb"
)
cols_fs_fio_rand_write=(
    "rw=randwrite, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 write aggrb"
    "rw=randwrite, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 write aggrb"
)
cols_fs_fio_falloc=(
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=falloc, iodepth=1 read aggrb"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=falloc, iodepth=1 write aggrb"
)
cols_fs_fio_read=(
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 read aggrb"
    "rw=read, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 read aggrb"
)
cols_fs_fio_write=(
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=libaio, iodepth=1 write aggrb"
    "rw=write, bs=32K-32K/32K-32K/32K-32K, ioengine=sync, iodepth=1 write aggrb"
)
cols_fs_write_read=(
    "cached write fallocate"
    "cache read"
    "cache read fallocate"
    "direct read"
    "direct read fallocate"
    "direct write"
    "direct write fallocate"
)
cols_fs_cached_write=(
    "cached write"
)

# XXX: count avg
function filter_blk_read() { sort -u -k1,1 "$@"; }
function filter_blk_read_cached() { filter_blk_read "$@"; }
function filter_blk_read_buffered() { filter_blk_read "$@"; }
function filter_fs_fio_rand_msec() { cat "$@"; }
function filter_fs_fio_msec() { cat "$@"; }
function filter_fs_fio_rand_read() { cat "$@"; }
function filter_fs_fio_rand_write() { cat "$@"; }
function filter_fs_fio_falloc() { cat "$@"; }
function filter_fs_fio_read() { cat "$@"; }
function filter_fs_fio_write() { cat "$@"; }
function filter_fs_write_read() { cat "$@"; }
function filter_fs_cached_write() { cat "$@"; }

# For permanent see fio.cfg
function key()
{
    local k="$@"

    k=${k/ bs=32K-32K\/32K-32K\/32K-32K, /} # permanent
    k=${k/ioengine=/} # understandable without prefix
    k=${k/iodepth=1 /} # permanent
    k=${k/rw=/} # understandable without prefix
    k=${k/ write /} # have in rw=
    k=${k/ read /} # have in rw=

    k=${k//\//_}
    k=${k// /_}

    echo $k
}
export -f key

function parse_size()
{
    awk -F'\t' -vOFS='\t' -vstr="$@" -f "$self/parse_size.awk"
}
export -f parse_size
function parallel_aggregate()
{
    awk -F'\t' -vOFS='\t' -f "$self/parallel_aggregate.awk"
}
export -f parallel_aggregate

function prepare_graph_plot()
{
    local t=$1

    eval local cols=( '"${cols_'$t'[@]}"' )
    local n=${#cols[@]}
    local i=0
    local c

    for c in "${cols[@]}"; do
        local linestyle=$((++i))

        linewrap=""
        if [ $n -gt $linestyle ]; then
            linewrap=", \\"
        fi

        cat <<-EOL
"$t.$(key $c).data" using 2:xticlabels(1) title "$(key $c)" with linespoint ls $linestyle $linewrap
EOL
    done
}
function prepare_graph_terminal()
{
    local o

    case "$format" in
        png)
            o+="set terminal pngcairo enhanced size $resulution font 'Gill Sans,9' rounded dashed"
            o+=$'\n'"set output '$t.plot.png'"
            ;;
        svg)
            o+="set terminal $format size $resulution font 'Gill Sans,9'"
            o+=$'\n'"set output '$t.plot.svg'"
            ;;
        *)
            o+="set terminal $format size $resulution font 'Gill Sans,9'"
            ;;
    esac

    echo "$o"
}
function prepare_graph()
{
    local t
    for t in "${types[@]}"; do
        cat > "$t.plot" <<EOL
set title "$t"
set xlabel "Disk"
set ylabel "Speed"

# Line style for axes
set style line 80 lt 0
set style line 80 lt rgb "#808080"

# Line style for grid
set style line 81 lt 3  # dashed
set style line 81 lt rgb "#808080" lw 0.5 # grey

set grid back linestyle 81
set border 3 back linestyle 80
set xtics nomirror rotate by -45
set ytics nomirror

set datafile separator "\t"
set format y "%b %B"

set style line 1 lt 1
set style line 2 lt 1
set style line 3 lt 1
set style line 4 lt 1
set style line 1 lt rgb "#A00000" lw 2 pt 7
set style line 2 lt rgb "#00A000" lw 2 pt 9
set style line 3 lt rgb "#5060D0" lw 2 pt 5
set style line 4 lt rgb "#F25900" lw 2 pt 13

$(prepare_graph_terminal)

plot \\
EOL

        prepare_graph_plot "$t" >> "$t.plot"

        cat >> "$t.plot" <<EOL
# XXX: Show min/max xtics more determine!
#    min_y = GPVAL_DATA_Y_MIN
#    max_y = GPVAL_DATA_Y_MAX
EOL
    done
}

function get_col()
{
    # XXX: for fs we need to change column for configuration name too?
    awk -vc="$@" -F'\t' -vOFS='\t' '{ if (NR == 1) { for (i = 0; i <= NF; ++i) { if (c == $i) { n = i; } } if (!n) { printf("No column {%s} in {%s}\n", c, $0) > "/dev/stderr"; exit(1); } if (debug) { printf("Column: %i\n", n) > "/dev/stderr"; } } else { if ($n) { print $1, $2, $n } } }'
}
export -f get_col
function get_cols()
{
    local cmd='tee '
    local i
    for i; do
        cmd+=">(get_col '$i') "
    done
    cmd+=' > /dev/null'
    eval $cmd
}
export -f get_cols

function build_graph_data()
{
    local cmd='tee '
    local t i=0

    # XXX: Still have issues with syncing sometimes
    rm -f .graph.lock && mkfifo .graph.lock
    for t in "${types[@]}"; do
        eval local cols=( '"${cols_'$t'[@]}"' )
        for c in "${cols[@]}"; do
            cmd+=">(get_col '$c' | parse_size | parallel_aggregate | filter_$t > '$t.$(key $c).data' && echo >> .graph.lock) "
            let ++i
        done
    done
    cmd+=' > /dev/null'
    eval $cmd

    while [ ! $i -eq 0 ]; do
        head -c1 .graph.lock >& /dev/null
        let i--
    done
}

function plot_graphs()
{
    local p
    for p in *.plot; do
        gnuplot -p "$p"
    done

    if [ "$format" = "png" ]; then
        montage *.plot.png -background none -geometry +0+0 sum.png
    fi
}

function main()
{
    prepare_graph
    build_graph_data
    plot_graphs
}

main
