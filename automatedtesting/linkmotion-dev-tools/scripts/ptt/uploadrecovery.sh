#!/bin/bash
#
# This script is used to flash recovery kernel and initrd to eMMC
# partition boot1. Optionally it can also enable recovery boot mode
# by writing "resc" to 0xd0000 and 0xe0000.
#
# The script requires fastboot to be installed. This can be found at least
# from Ubuntu repos.
# The ptt-version of u-boot is also required as it exposes the fastboot
# interface. This can be found in rpm package u-boot-imx6-halti-ptt


set -e

print_help()
{
    echo "Usage ${0} -u ptt_uboot -i recovery_image [--enable]"
    echo "If ptt_uboot is not supplied, the script tries to"
    echo "find u-boot-halti-ptt.imx."
    echo "Requires path to imx_usb in PATH or IMX_USB_PATH environment variable"
    echo "Root privileges required for accessing USB device."
    echo "--enable enables recovery boot."
}

cleanup()
{
    return_value=$?
    trap - EXIT INT TERM ERR
    echo "Cleaning up"
    if [ -f resc ]; then
        rm resc
    fi
    exit $return_value
}

init()
{
    enable_recovery=0
    recovery_image=""
    ptt_uboot="u-boot-halti-ptt.imx"
    error_code=0
}

parse_arguments()
{
    getopt --test > /dev/null || error_code=$?
    if [[ error_code -ne 4 ]]; then
        echo "I’m sorry, `getopt --test` failed in this environment."
        exit 1
    fi

    SHORT="u:i:he"
    LONG="pttuboot:,image:,enable,help"

    # -temporarily store output to be able to check for errors
    # -activate advanced mode getopt quoting e.g. via “--options”
    # -pass arguments only via   -- "$@"   to separate them correctly
    PARSED=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")
    if [[ $? -ne 0 ]]; then
        # e.g. $? == 1
        #  then getopt has complained about wrong arguments to stdout
        print_help
        exit 2
    fi
    # use eval with "$PARSED" to properly handle the quoting
    eval set -- "$PARSED"

    # now enjoy the options in order and nicely split until we see --
    while true; do
        case "$1" in
            -u|--pttuboot)
                ptt_uboot="$2"
                shift 2
                ;;
            -i|--image)
                recovery_image="$2"
                shift 2
                ;;
            -e|--enable)
                enable_recovery=1
                shift
                ;;
            -h|--help)
                print_help
                exit
                ;;
            --)
                shift
                break
                ;;
            *)
                echo "Programming error"
                exit 3
                ;;
        esac
    done

    # handle non-option arguments
    #if [[ $# -lt 3 ]]; then
    #    print_help
    #    exit 4
    #fi

    echo "ptt-uboot: $ptt_uboot, recovery_kernel: $recovery_kernel, recovery_image: $recovery_image, enable_recovery: $enable_recovery"
}

# Execution starts here
trap cleanup EXIT INT TERM ERR
init
parse_arguments "$@"

if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
    exit $?
fi

if [ ! -f ${ptt_uboot} ] || [ ! -f ${recovery_image} ]; then
    echo "Could not find all the necessary files for flashing"
    print_help
    exit 5
fi

error_code=0
imx_usb ${ptt_uboot} || error_code=$?
if [ $error_code -ne 0 ]; then
    echo "Could not find imx_usb in PATH, trying IMX_USB_PATH"
    ${IMX_USB_PATH}/imx_usb ${ptt_uboot}
fi

fastboot flash mmc:hwpart2:0x0 ${recovery_image}

if [ $enable_recovery -eq 1 ]; then
    echo -e "00000000: 72657363" | xxd -r > resc
    fastboot flash spi:0xd0000 resc
    fastboot flash spi:0xe0000 resc
fi
