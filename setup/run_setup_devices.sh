#!/usr/bin/env bash

setups=(
    generic
    raid56
    lvm_all
    lvm_works

    lvm_ext4_works6
    lvm_tux3_works6
    lvm_ext4_works4
    lvm_tux3_works4

    md2_ext4
    md2_tux3
    md3_ext4
    md3_tux3
    md4_ext4
    md4_tux3
)

dir=bench-$(date +%s)
mkdir -p $dir && cd $dir

function raw_timing()
{
    local prefix=$(printf %s $@)
    # raw timing
    setup_devices.sh -Dt $@ /dev/sd{a..l} >& ${s}.bench.blk.$prefix
    setup_devices.sh -Dt $@ /dev/mapper/*lg* >& ${s}.bench.blk.lg.$prefix
    setup_devices.sh -Dt $@ /dev/mapper/*vg >& ${s}.bench.blk.vg.$prefix
    setup_devices.sh -Dt $@ /dev/md/* >& ${s}.bench.blk.md.$prefix
}

for s in ${setups[@]}; do
    setup_devices.sh -vRD /dev/sd{a..l} >& ${s}.revert
    setup_devices.sh -vDs$s /dev/sd{a..l} >& ${s}.setup

    setup_devices.sh -vDp /dev/sd{a..l} >& ${s}.print

    raw_timing -B32K -C10000
    raw_timing -B32M -C100

    # via fs timing
    setup_devices.sh -Dtm /work_* >& ${s}.bench.fs
    setup_devices.sh -PDtm /work_* >& ${s}.bench.fs.parallel
done
