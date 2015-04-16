#!/usr/bin/env bash

setups=(
    generic
    raid56
    lvm_all
    lvm_works

    lvm_ext4_works6
    lvm_xfs_works6
    lvm_ext4_works4
    lvm_xfs_works4

    md2_ext4
    md2_xfs
    md3_ext4
    md3_xfs
    md4_ext4
    md4_xfs
)

self=$(readlink -f $(dirname $0))
cd $1

function parse_mount_output()
{
    fgrep -A10000 '+ mount' $@ | grep /work
}
function parse_mnt()
{
    parse_mount_output $@ | cut -d' ' -f3
}
function parse_blk()
{
    parse_mount_output $@ | cut -d' ' -f1
}

function parse_bench_blk()
{
    local type=${1/*.}
    awk -vprefix=$type -f $self/parse_bench_blk.awk $@
}
function parse_bench_fs()
{
    awk -f $self/parse_bench_fs.awk $@
}
function parse_bench_blks()
{
    for bs in 32K 32M; do
        for d in "" lg. md.; do
            parse_bench_blk ${@}.${d}-B${bs}-C*
        done
    done
}

function create_table()
{
    awk -f $self/table.awk $@
}
function append()
{
    local l
    while read l; do echo "$@$l"; done
}
function render_ascii_table()
{
    column -ts$'\t'
}

for s in ${setups[@]}; do
    [ -f ${s}.setup ] || continue

    # get devices configuration
    mnt=$(parse_mnt ${s}.print)
    blk=$(parse_blk ${s}.print)

    (
        parse_bench_blks ${s}.bench.blk
        parse_bench_fs ${s}.bench.fs
        parse_bench_fs ${s}.bench.fs.parallel | append parallel_
    ) | append $s$'\t'
done | create_table
