#!/bin/bash
#
# This script is used to flash u-boot to SPI NOR. Optionally it can also
# erase u-boot environment when flashing.
#
# The script requires fastboot to be installed. This can be found at least
# from Ubuntu repos.
# The ptt-version of u-boot is also required as it exposes the fastboot
# interface. This can be found in rpm package u-boot-imx6-halti-ptt


set -e

print_help()
{
    echo "Usage ${0} -u ptt_uboot -i product_uboot [--erase-env]"
    echo "If ptt_uboot not set tries to find u-boot-halti-ptt.imx from current dir"
    echo "Requires path to imx_usb in PATH or IMX_USB_PATH environment variable"
    echo "Root privileges required for accessing USB device."
}

cleanup()
{
    return_value=$?
    trap - EXIT INT TERM ERR
    echo "Cleaning up"
    exit $return_value
}

init()
{
    erase_size="0x100000"
    input_file=""
    ptt_uboot="u-boot-halti-ptt.imx"
    error_code=0
}

parse_arguments()
{
    getopt --test > /dev/null || error_code=$?
    if [[ $error_code -ne 4 ]]; then
        echo "I’m sorry, `getopt --test` failed in this environment."
        exit 1
    fi

    SHORT=u:i:he
    LONG=ptt-uboot:,inputfile:,erase-env,help

    # -temporarily store output to be able to check for errors
    # -activate advanced mode getopt quoting e.g. via “--options”
    # -pass arguments only via   -- "$@"   to separate them correctly
    PARSED=$(getopt --options $SHORT --longoptions $LONG --name "$0" -- "$@")
    if [[ $? -ne 0 ]]; then
        # e.g. $? == 1
        #  then getopt has complained about wrong arguments to stdout
        exit 2
    fi
    # use eval with "$PARSED" to properly handle the quoting
    eval set -- "$PARSED"

    # now enjoy the options in order and nicely split until we see --
    while true; do
        case "$1" in
            -u|--ptt-uboot)
                ptt_uboot="$2"
                shift 2
                ;;
            -i|--inputfile)
                input_file="$2"
                shift 2
                ;;
            -h|--help)
                print_help
                exit
                ;;
            -e|--erase-env)
                erase_size="0x200000"
                shift
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

    echo "ptt-uboot: $ptt_uboot, inputfile: $input_file"
}

# Execution starts here
if [ $# -lt 2 ]
then
    print_help
    exit 4
fi

trap cleanup EXIT INT TERM ERR
init
parse_arguments "$@"

if [ ! -f ${ptt_uboot} ] || [ ! -f ${input_file} ]
then
    echo "Could not find all necessary files"
    exit 5
fi

if [ $EUID != 0 ]; then
    sudo -E "$0" "$@"
    exit $?
fi

error_code=0
imx_usb ${ptt_uboot} || error_code=$?
if [ $error_code -ne 0 ]; then
    ${IMX_USB_PATH}/imx_usb ${ptt_uboot}
fi

fastboot erase spi:0x0:${erase_size}
fastboot flash spi:0x400 ${input_file}
