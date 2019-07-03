#!/bin/bash

# MyISP home
NAME="home"
ISP="MyISP"
VENDOR="Dasan"
HWVER="V3.0"
SWVER="V2.30.20P6T14S"


FIRMWARE_IN="./3FE45464AOCK21.upf"
FIRMWARE_OUT="./ZIZA-${ISP}.${NAME}-${SWVER}.bin"
FMK_EXTRACT="./firmware-mod-kit/extract-firmware.sh"
FMK_BUILD="./firmware-mod-kit/build-firmware.sh"
FMK_EXTRACTED="./fmk/"
CRC32="./firmware-mod-kit/src/crcalc/crc32"

BUILD_TIME=`date '+%Y-%m-%d %H:%M:%S'`
## date displays the current time  --> 2019-07-01 11:24:09


function firmware_patch_src {
    cd "${FMK_EXTRACTED}rootfs/"
##  cd firmware-mod-kit/fmk/rootfs/
## --------------------- Update show_version ------------------------------------------------------------------------
    sed -i -r "s/Hardware Version:          .+/Hardware Version:          ${HWVER}/1"      ./show_version 2>/dev/null
    sed -i -r "s/Client Software Version:   .+/Client Software Version:   ${SWVER}/1"      ./show_version 2>/dev/null

## sed -i replaces behind the scene in the file "show_version" Only the 1st occurance(/1 flag)
## The > operator redirects the output usually to a file but it can be to a device. You can also use >> to append  
## > file redirects stdout to file
## 1> file redirects stdout to file
## 2> file redirects stderr to file
## &> file redirects stdout and stderr to file
## /dev/null is the null device it takes any input you want and throws it away. It can be used to suppress any output.
#    sed -i -r "s/Build User:                .+/Build User:                chingwa/1"     ./show_version 2>/dev/null
#    sed -i -r "s/Build Time:                .+/Build Time:                ${BUILD_TIME}/1" ./show_version 2>/dev/null

## --------------------- Update version -----------------------------------------------------------------------
#    sed -i -r "s/Build User          : .+/Build User          : chingwa/1"             ./version 2>/dev/null
#    sed -i -r "s/Build Time          : .+/Build Time          : ${BUILD_TIME}/1"         ./version 2>/dev/null
    sed -i -r "s/Client Version      : .+/Client Version      : ${SWVER}/1"              ./version 2>/dev/null
    sed -i -r "s/Client ONU Version  : .+/Client ONU Version  : ${SWVER}/1"              ./version 2>/dev/null
    sed -i -r "s/VENDOR ID           : .+/VENDOR ID           : ${VENDOR}/1"             ./version 2>/dev/null
    sed -i -r "s/Hardware Version    : .+/Hardware Version    : ${HWVER}/1"              ./version 2>/dev/null

    cd -
## cd - changes to the previous working directory    
}



function firmware_patch_img {
## dd if=$FIRMWARE_OUT bs=1 skip=124 count=32 | hexdump -C  --> Can be used to display content of 32 bytes before change

dd if=/dev/zero of=$FIRMWARE_OUT bs=1 seek=124 count=32 conv=notrunc
##  write 32 bytes of zeros(/dev/zero) to a file starting at the offset 124 and don't truncate the output

    echo -n $SWVER | dd of=$FIRMWARE_OUT bs=1 seek=124 conv=notrunc
## write $SWVER to the previously zeroed out area starting at the offset 124

    dd if=/dev/zero of=$FIRMWARE_OUT bs=1 seek=632 count=32 conv=notrunc
##  write 32 bytes of zeros(/dev/zero) to a file starting at the offset 632 and don't truncate the output

    echo -n $SWVER | dd of=$FIRMWARE_OUT bs=1 seek=632 conv=notrunc
## write $SWVER to the previously zeroed out area starting at the offset 124

    dd if=/dev/zero of=$FIRMWARE_OUT bs=1 seek=664 count=32 conv=notrunc
##  write 32 bytes of zeros(/dev/zero) to a file starting at the offset 664 and don't truncate the output

    echo -n $VENDOR | dd of=$FIRMWARE_OUT bs=1 seek=664 conv=notrunc
## write $VENDOR to the previously zeroed out area starting at the offset 664

## --------------------- Update created time ------------------------------------------------------------------------
# binwalk displays created time for squashfs at 0x140200. Update created time later at the image offset 0x208
    stime=`binwalk $FIRMWARE_OUT | grep 0x140200 | grep -oP "created\: ([0-9\-\: ]+)" | sed -e "s/created: //g"`
## binwalk displays -->  2017-07-19 09:30:18  or type --> echo $stime

    itime=`date --date="${stime}" +"%s"`
## echo $itime -->  1500471018  
## %s --> seconds since 1970 (epoch time)

    itime=$(($itime + 3600 * 3 + 1))
# Add 3 hours
## echo $itime --> 1500481819

    htime=`echo "obase=16; ${itime}" | bc`
## convert from decimal to hex(obase=16) and pipe it to bc (basic calculator)
## echo $htime --> 596F891B

    htime=$(byte_hex2bin $htime 1)
## reverse and convert 596F891B to binary format with \x prefix
## Just for info check existing time at the offset 0x208 --> ab 26 6f 59 byte reverse=596f26ab dec=1500456619
## dd if=$FIRMWARE_IN bs=1 skip=520 count=4 | hexdump -C  
       
    echo -e "${htime}" | dd of=$FIRMWARE_OUT bs=1 seek=520 count=4 conv=notrunc
## write new "created time" value \x1B\x89\x6F\x59 as 4 bytes at the offset 520<->0x208   
}

## --------------------- 4 bytes hex2bin conversion -----------------------------------------------------------
function byte_hex2bin {
    v=$1
    if [ $2 -eq 1 ]; then
	echo "\x${v:6:2}\x${v:4:2}\x${v:2:2}\x${v:0:2}"
## change the byte order e.g. \x1B\x89\x6F\x59	
    else
	echo "\x${v:0:2}\x${v:2:2}\x${v:4:2}\x${v:6:2}"
## don't change the byte order e.g. \x59\x6F\x89\x1B
    fi
}

## --------------------- Calculate CRC -----------------------------------------------------------------------
function firmware_crc {
    dd if=/dev/zero of=$FIRMWARE_OUT bs=1 seek=$1 count=4 conv=notrunc
## zero out 4 bytes where CRC32 is stored the offset 0x21C 0x220 0x68 (540 544 104)

    crc=`$CRC32 $FIRMWARE_OUT $3 $4 | tail -n 1 | awk '{print $2}' | sed "s/0x//1"`
## calculate CRC32 $offset $length (get the last line, 2nd colum and remove 1st instance of 0x)

    crc=$(byte_hex2bin $crc $2)
## reverse 4 bytes or not. It depends if variable $2 is 1 or 0

    echo -e "${crc}" | dd of=$FIRMWARE_OUT bs=1 seek=$1 count=4 conv=notrunc
## write 4 bytes checksum to the previously zeroed out location $1
}

rm -rf $FMK_EXTRACTED
$FMK_EXTRACT $FIRMWARE_IN
firmware_patch_src
$FMK_BUILD
mv "${FMK_EXTRACTED}new-firmware.bin" $FIRMWARE_OUT
firmware_patch_img

--------------- Some reference info. Headers and CRC taken from the source firmware  ---------------------
## 27 05 19 56 uImage/U-boot Magic Number at 0x400
## 48 39 EC 66 uImage header 0x400-0x43F --> CRC32 checksum (0x404-0x407) no reverse

## Great job on finding these checksum locations!
## firmware_crc                $CRC32_offset     $revers_or_not    $offset         $length
firmware_crc 540 1 1024 3669504 # 0x21C,<><------>reverse bytes,<->0x400,<><------>0x380200],<---->// BE F3 D0 10(old CRC32)
firmware_crc 544 1 512  512     # 0x220,<><------>reverse bytes,<->0x200,<><--------->0x400],<---->// 6E F9 23 20(old CRC32)
firmware_crc 104 0 0    3670528 # 0x68, <><----->do not reverse,<--->0x0,<><------>0x380200]<----->// F1 5D D3 F4(old CRC32)
#rm -rf $FMK_EXTRACTED
