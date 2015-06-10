#!/usr/bin/env bash

# XXX: be careful and don't use it on prod.
# Configure (lvm; md; block devs) for 12HDD machine

set -e

function assert()
{
    local SIGABRT=6
    if ! $@; then
        echo "$@: failed" >&2
        exit $SIGABRT
    fi
}
function mounted() { grep -q "^$1 " /proc/mounts; }

function mkfs_tux3() { tux3 mkfs $@; }
function create_tux3()
{
    mkfs_tux3 $@
}
function create_ext4()
{
    mke2fs -F -t ext4 -O extents -I $((1<<12)) -i $((1<<17)) -m 0 -q $@
}
function create_fs()
{
    local fs=$1
    shift

    create_$fs $@
}
function create_partition()
{
    parted -s $@ mklabel GPT
    parted $@ mkpart primary ext4 2048s 100%
}
function create_lvm()
{
    local vg=$1
    local lv="$2"
    shift 2

    pvcreate --yes -ff $@
    vgcreate $vg $@

    lvs=($lv)
    n=${#lvs[@]}
    for i in ${lvs[@]}; do
        lvcreate -n $i -l $(( 100 / n ))%VG $vg
    done
}

function md()
{
    local name=$1
    shift
    local opts devs n=0
    local i
    for i; do
        if [ "${i:0:2}" = "--" ]; then
            opts+=" $i"
        else
            devs+=" $i"
            let ++n
        fi
    done
    yes | mdadm --create --verbose /dev/md/$name \
          --chunk=$raidChunkSize --metadata 1.2 --force \
          --raid-devices=$n $opts $devs
    # blockdev --setra 65536 /dev/md/$name
}
function setup_md_mirror()
{
    local name=$1
    shift
    md $name --level=mirror $@
}
function setup_md_mirror_clean()
{
    local name=$1
    shift
    md $name --assume-clean --level=mirror $@
}
function setup_md_raid10_clean()
{
    local name=$1
    shift
    md $name --assume-clean --level=raid10 --layout=o2 $@
}
function setup_md_raid5_clean()
{
    local name=$1
    shift
    md $name --assume-clean --level=raid5 $@
}
function setup_md_raid6_clean()
{
    local name=$1
    shift
    md $name --assume-clean --level=raid6 $@
}
function setup_md_stripe()
{
    local name=$1
    shift
    md $name --level=stripe $@
}

function drop_file_cache()
{
    dd oflag=nocache conv=notrunc,fdatasync count=0 of=$@ >& /dev/null
}
function dd_test()
{
    dd bs=$benchmarksBs count=$benchmarksCountBs $@
}
function test_speed_file()
{
    local f=$1
    echo "Perform cached write on $f"
    dd_test if=/dev/zero of=$f
    echo "Perform direct write on $f"
    dd_test if=/dev/zero of=$f oflag=direct
    drop_file_cache $f
    echo "Perform cache read on $f"
    dd_test of=/dev/null if=$f
    echo "Perform direct read on $f"
    dd_test of=/dev/null if=$f iflag=direct
}
function test_fio()
{
    echo "Fio for $dir"
    cd $dir
    # XXX: --latency-log --bandwidth-log
    fio $fioCfg
    cd -
}
function test_speed()
{
    local dir=$1
    local f=$dir/.w
    test_speed_file $f

    echo "Preallocated file $f"
    rm $f && fallocate -l4G $f
    drop_file_cache $f
    test_speed_file $f
    rm $f

    test_fio
}
function setup_grants()
{
    grants.sh $@
}
function setup_mount_impl()
{
    mkdir -p $2
    mount $1 $2

    if [ $doBenchmarks -eq 1 ]; then
        test_speed $2
    fi
}
function setup_mount_bl()
{
    setup_grants $1
    mkdir -p $1/{db,logs,increments,ipipes,iremotes}
}
function setup_mount()
{
    setup_mount_impl $@
    setup_mount_bl $2
}
#
# Main setup routine
#
function setup_devices_generic()
{
    # regular fs
    create_partition $1
    create_ext4 ${1}1
    setup_mount ${1}1 /work_ext4
    shift
    create_partition $1
    create_tux3 ${1}1
    setup_mount ${1}1 /work_tux3
    shift
    # regular lvm
    create_lvm ext4-vg ext4-lg $1 $2
    create_ext4 /dev/ext4-vg/ext4-lg
    setup_mount /dev/ext4-vg/ext4-lg /work_lvm
    shift 2
    # md over lvm
    create_lvm ext4raid0-vg ext4raid0-lg $1 $2
    setup_md_stripe lvm /dev/ext4raid0-vg/ext4raid0-lg
    create_ext4 /dev/md/lvm
    setup_mount /dev/md/lvm /work_md_lvm
    shift 2
    # other     : md
    setup_md_mirror mirror $1 $2
    create_ext4 /dev/md/mirror
    setup_mount /dev/md/mirror /work_md_mirror
    shift 2
    setup_md_mirror_clean mirror_clean $1 $2
    create_ext4 /dev/md/mirror_clean
    setup_mount /dev/md/mirror_clean /work_md_mirror_clean
    shift 2
    setup_md_stripe stripe $1 $2
    create_ext4 /dev/md/stripe
    setup_mount /dev/md/stripe /work_md_stripe
    shift 2
}
function setup_devices_raid56()
{
    # tux3 *don't* uses blkid_topology_get_minimum_io_size(), so there is no need in
    # bypassing this options for it
    local ext4opts="-E stride=$((raidChunkSize/4)),stripe_width=$(((raidChunkSize/4)*(3-1)))"

    # raid5 ext4
    setup_md_raid5_clean raid5_ext4_clean $1 $2 $3
    create_ext4 $ext4opts /dev/md/raid5_ext4_clean
    setup_mount /dev/md/raid5_ext4_clean /work_md_raid5_ext4_clean
    shift 3
    # raid6 ext4
    setup_md_raid6_clean raid6_ext4_clean $1 $2 $3 $4 $5 $6
    create_ext4 $ext4opts /dev/md/raid6_ext4_clean
    setup_mount /dev/md/raid6_ext4_clean /work_md_raid6_ext4_clean
    shift 6

    # raid5 tux3
    setup_md_raid5_clean raid5_tux3_clean $1 $2 $3
    create_tux3 /dev/md/raid5_tux3_clean
    setup_mount /dev/md/raid5_tux3_clean /work_md_raid5_tux3_clean
    shift 3
}
function setup_devices_lvm_all()
{
    # TODO:
    # we need to do parallel testing for this confguration
    # (and we could do this very simple using db-indexes, to avoid requiring
    # increments, and also we need to do this for other targets).
    #
    # we also need to test tux3
    create_lvm ext4-vg ext4-lg $@
    create_ext4 /dev/ext4-vg/ext4-lg
    setup_mount /dev/ext4-vg/ext4-lg /work_lvm_all
    shift 12
}
function setup_devices_lvm_works()
{
    create_lvm ext4-vg "$(echo ext4-lg-{1..4})" $@
    for i in {1..4}; do
        create_ext4 /dev/ext4-vg/ext4-lg-$i
        setup_mount /dev/ext4-vg/ext4-lg-$i /work_lvm_$i
    done
}
# one lvm for 6 works
function _setup_devices_lvm_all_works()
{
    local fs=$1
    shift
    local works=$1
    shift

    create_lvm $fs-vg $fs-lg $@
    create_fs $fs /dev/$fs-vg/$fs-lg
    setup_mount_impl /dev/$fs-vg/$fs-lg /.work_lvm_all

    local i
    for i in $(seq 1 $works); do
        mkdir /.work_lvm_all/$i
        ln -s /.work_lvm_all/$i /work_lvm_all_$i
        setup_mount_bl /work_lvm_all_${fs}_$i
    done
}
function setup_devices_lvm_ext4_works6() { _setup_devices_lvm_all_works ext4 6 $@ ; }
function setup_devices_lvm_tux3_works6() { _setup_devices_lvm_all_works tux3 6 $@ ; }
function setup_devices_lvm_ext4_works4() { _setup_devices_lvm_all_works ext4 4 $@ ; }
function setup_devices_lvm_tux3_works4() { _setup_devices_lvm_all_works tux3 4 $@ ; }
function _setup_devices_md_impl()
{
    function replace()
    {
        local s=$1
        s=${s//%fs%/$2}
        s=${s//%i%/$3}
        echo $s
    }

    # XXX: getopts
    local md_pattern=$1
    shift
    local work_pattern=$1
    shift
    local fs=$1
    shift
    local n=($1)
    local l=${#n[@]}
    shift

    local i=0
    while [ $# -gt 0 ]; do
        let ++i

        local md_name=$(replace $md_pattern $fs $i)
        local devs=()
        local j
        [ $i -ge $l ] && n_devs=${n[l - 1]} || n_devs=${n[i - 1]}
        local level=mirror
        # Different level for specific N
        if [[ $n_devs =~ ^([0-9]*)_([a-z0-9]*)$ ]]; then
            n_devs=${BASH_REMATCH[1]}
            level=${BASH_REMATCH[2]}
        fi
        # TODO: into helper?
        for (( j = 0; j < $n_devs; ++j )); do
            devs+=($1)
            shift
        done
        setup_md_${level}_clean $md_name ${devs[@]}
        create_fs $fs /dev/md/$md_name

        local work_name=$(replace $work_pattern $fs $i)
        setup_mount /dev/md/$md_name $work_name
    done
}
function _setup_devices_md()
{
    _setup_devices_md_impl "mirror_clean_%fs%_%i%" "/work_md_mirror_clean_%fs%_%i%" "$@"
}
function setup_devices_md2_ext4() { _setup_devices_md ext4 2 $@ ; }
function setup_devices_md2_tux3() { _setup_devices_md tux3 2 $@ ; }
function setup_devices_md3_ext4() { _setup_devices_md ext4 3 $@ ; }
function setup_devices_md3_tux3() { _setup_devices_md tux3 3 $@ ; }
function setup_devices_md4_ext4() { _setup_devices_md ext4 4 $@ ; }
function setup_devices_md4_tux3() { _setup_devices_md tux3 4 $@ ; }

function _setup_devices_md24_ext4() { _setup_devices_md_impl "work%i%" "/work%i%" ext4 "2 2 2 2 4_raid10" $@ ; }
function setup_devices_md_prod() { _setup_devices_md24_ext4 $@; }

self=$(readlink -f $(dirname $0))
dryRun=1
doBenchmarks=0
doBenchmarksMnt=0
doSetupDevices=
doRevert=0
raidChunkSize=512 # kb
benchmarksCountBs=100000
benchmarksBs=32K
fioCfg=$self/fio.cfg
doBenchmarksInParallel=0
function printUsage()
{
    echo "$0 [ OPTS ] [ -- ] DEVICES"
    echo
    echo " -v     - verbose mode (set -x)"
    echo " -D     - disable dry run mode (turned on by default)"
    echo " -R     - revert"
    echo " -f     - fio config"
    echo " -p     - print/display configuration"
    echo " -t     - perform timing benchmarks (option from hdparm)"
    echo " -m     - perform timing benchmarks for mount points"
    echo " -P     - do mnt benchmarks in parallel, and hence this is the different devices it must be ok"
    echo " -s     - do setup devices with specific helper"
    echo " -c     - change raid chunk size for mdadm"
    echo " -C     - change benchmarks number of bs'es"
    echo " -C     - change benchmarks bs"
    echo " -h     - help"
    echo
    echo "Examples (if root disks are last, IOW /dev/sd[nm]):"
    echo " ./setup_devices.sh /dev/sd{a..l}"
    echo "And don't forget to install PATH to:"
    echo " - grants.sh"
    echo " - mke2fs (new version)"
    echo " - tux3 (new version)"
    echo
    echo "Available setupers:"
    echo "- generic"
    echo "- raid56"
    echo "- lvm_all"
    echo "- lvm_works"
    echo
    echo "- lvm_ext4_works6"
    echo "- lvm_tux3_works6"
    echo "- lvm_ext4_works4"
    echo "- lvm_tux3_works4"
    echo
    echo "- md2_ext4"
    echo "- md2_tux3"
    echo "- md3_ext4"
    echo "- md3_tux3"
    echo "- md4_ext4"
    echo "- md4_tux3"
    echo
    echo "- md_prod"
    exit 0
}
function setup_dryrun()
{
    function parted() { echo parted "$@"; }
    function mdadm() { echo mdadm "$@"; }
    function mkfs_tux3() { echo tux3 mkfs "$@"; }
    function mke2fs() { echo mke2fs "$@"; }
    function vgcreate() { echo vgcreate "$@"; }
    function lvcreate() { echo lvcreate "$@"; }
    function pvcreate() { echo pvcreate "$@"; }
    function mount() { echo mount "$@"; }
    function mkdir() { echo mkdir "$@"; }
    function setup_grants() { echo grants.sh "$@"; }

    function hdparm() { echo hdparm "$@"; }
    function dd() { echo dd "$@"; }
    function fallocate() { echo fallocate "$@"; }
    function rm() { echo rm "$@"; }
}
function options()
{
    local OPTIND OPTARG o

    while getopts "vDRf:phtmc:C:s:B:P" o; do
        case $o in
            v) set -x ;;
            D) dryRun=0 ;;
            R) doRevert=1 ;;
            f) fioCfg=$OPTARG ;;
            p) print_configuration ;;
            t) doBenchmarks=1 ;;
            s) doSetupDevices=$OPTARG ;;
            m) doBenchmarksMnt=1 ;;
            P) doBenchmarksInParallel=1 ;;
            c) raidChunkSize=$OPTARG ;;
            C) benchmarksCountBs=$OPTARG ;;
            B) benchmarksBs=$OPTARG ;;
            [?h]) printUsage ;;
        esac
    done
    shift $((OPTIND-1))

    devices=("$@")

    if [ $dryRun == 1 ]; then
        setup_dryrun
    fi
}

function require_root()
{
    if [ $dryRun = 0 ] && [ ! $UID = 0 ]; then
        echo "Must be root" >&2
        exit 1
    fi
}
function require_not_mounted()
{
    for i; do
        if mounted ${i}1; then
            echo "$i mounted" >&2
            if [ $dryRun -eq 0 ]; then
                exit 1
            fi
        fi
    done
}
function disable_md_safe_mode_delay()
{
    for f in /sys/block/md*/safe_mode_delay; do
        echo 0 >| $f
    done
}
function test_mq_enabled()
{
    test $(cat /sys/module/scsi_mod/parameters/use_blk_mq) = Y
}
function setup_sys()
{
    disable_md_safe_mode_delay
    test_mq_enabled
}
function reset_table() { dd if=/dev/zero of=$@ bs=512k count=1 >& /dev/null; }
function revert()
{
    for w in /work? /work_* /.work_*; do
        umount $w && rmdir $w || echo "$w: not mounted"
    done
    mdadm --stop --scan || echo "No more md"
    vgremove -f /dev/*vg || echo "No more vg"
    pvremove --yes -ff $@ || echo "No more pv"
    lvremove -f /dev/mapper/*lg* || echo "No more lv"
    mdadm --stop --scan || echo "No more md"
    for i; do reset_table $i; done

    # do final revert for multiple works on one lvm
    rm -fr /work_* /work?
}
function print_configuration()
{
    vgdisplay
    pvdisplay
    lvdisplay

    mdadm --detail /dev/md/*

    mount
}
function run_raw_benchmarks()
{
    if [ $doBenchmarks -eq 0 ]; then
        return
    fi

    local dev
    for dev; do
        hdparm -tT $dev
    done
}

function setup_devices()
{
    numberOfDevices=${#devices[@]}
    assert test $numberOfDevices = 12

    require_not_mounted ${devices[@]}
    setup_devices_$@ ${devices[@]}
    # setup_sys
    run_raw_benchmarks ${devices[@]}
}

function main()
{
    options "$@"
    require_root

    if [ $doRevert -eq 1 ]; then
        revert ${devices[@]}
    fi
    if [ ! "$doSetupDevices" = "" ]; then
        setup_devices $doSetupDevices
    fi
    if [ $doBenchmarks -eq 1 ] && [ "$doSetupDevices" = "" ]; then
        if [ $doBenchmarksMnt -eq 1 ]; then
            for i in ${devices[@]}; do
                if [ $doBenchmarksInParallel -eq 1 ]; then
                    test_speed $i &
                else
                    test_speed $i
                fi
            done
            if [ $doBenchmarksInParallel -eq 1 ]; then
                wait
            fi
        else
            run_raw_benchmarks ${devices[@]}
        fi
    fi
}

main "$@"
