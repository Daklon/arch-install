#! /bin/bash

TMP_PENDRIVE_DIR="/mnt/pendrive"
TMP_ROOT_DIR="/mnt/root"
cipher_list="
aes-cbc-128b
aes-cbc-256b
aes-xts-256b
aes-xts-512b
serpent-cbc-128b
serpent-cbc-256b
serpent-xts-256b
serpent-xts-512b
twofish-cbc-128b
twofish-cbc-256b
twofish-xts-128b
twofish-xts-256b"

hash_list="
sha1
sha256
sha512
ripemd160
whirlpool"

function menu() {
    configure_basic
    echo "Welcome to my arch install wizard"
    new_hostname=$(dialog --stdout --backtitle "Arch Install wizard" --title "Hostname" --inputbox "Introduce the desired hostname" 0 0)
    #available_diks=$(fdisk -l)
    NUMBER_LINE="$(lsblk | awk '/sd[a-z]/ { print }' | wc -l)"
    for (( i = 1; i <= $NUMBER_LINE; i++ )); do
        DISK="$(lsblk | grep sd | awk ' NR=='$i'{ print $1 }' )"
        SIZE="$(lsblk | grep sd | awk ' NR=='$i'{ print $4 }' )"
        MENU+="$DISK $SIZE "
    done
    disk=$(dialog --stdout --clear --backtitle "Arch Install wizard" --title "Choosing destination" --menu "Select the disk where you want to install arch" 0 0 0 $MENU)
    exitStatus=$?
    MENU=$(echo $MENU | sed 's|'$disk' .[0-9]*G ||g')
    disk="/dev/"$disk
    dialog --stdout --backtitle "Arch Install wizard" --title "Disk secure cleaning" --yesno "Do you want to fully delete the disk first?" 0 0
    exitStatus=$?
    if [ $exitStatus -eq 0 ]; then
        delete_times=$(dialog --stdout --backtitle "Arch Install wizard" --title "Disk secure cleaning" --inputbox "How many times must the disk be deleted?" 0 0)
        clean_disk $delete_times $disk
    fi
    generate_temp_dirs
    dialog --stdout --backtitle "Arch Install wizard" --title "Disk encryption" --yesno "Do you want to have the disk encrypted?" 0 0
    if [ $? -eq 0 ]; then
        dialog --stdout --backtitle "Arch Install wizard" --title "Disk encryption" --yesno "Do you want to have a remote luks header?" 0 0
        remote_headers=$?
        if [ $? -eq 0 ]; then
            pendrive=$(dialog --stdout --clear --backtitle "Arch Install wizard" --title "Choosing destination" --menu "Select the disk where you want to store boot and remote headers" 0 0 0 $MENU)
        fi
        cipher=$(dialog --stdout --no-items --backtitle "Arch Install wizard" --title "Disk encryption" --menu "Select the cipher algorithm" 0 0 0 $cipher_list)
        key_size=$(echo $cipher | awk -F "-" '{print substr($3, 1, length($3)-1)}')
        cipher=$(echo $cipher | awk -F "-" '{print $1"-"$2}')
        hash=$(dialog --stdout --no-items --backtitle "Arch Install wizard" --title "Disk encryption" --menu "Select the hash algortihm" 0 0 0 $hash_list)
        iter_time=$(dialog --stdout --backtitle "Arch Install wizard" --title "Disk encryption" --inputbox "Introduce iter-time(ms)" 0 0)
        if [ $remote_headers -eq 0 ]; then
            set -e
            encrypt_disk_remote $disk /home/header.img $hash $key_size $cipher-plain $iter_time
            decrypt_disk_remote /home/header.img /dev/sda enc
            configure_disk_remote /dev/mapper/enc 2 /dev/enc/root $TMP_ROOT_DIR /dev/enc/swap
        else
            set -e
            encrypt_disk $disk $hash $key_size $cipher $iter_time
            decrypt_disk /dev/sda enc
        fi
    else
        set -e
        configure_disk $disk
    fi
    install_arch base $new_hostname
}    

function dialog_menu()
{
    dialog --clear \
            --backtitle "$2" \
            --title "$3" \
            --menu $4 0 0 0 $5
}

function configure_basic() {
    loadkeys es
    timedatectl set-ntp true
    pacman -Sy && pacman -S dialog --noconfirm
}

function clean_disk(){
    shred -v -n $1 $2
}

function generate_temp_dirs() {
    mkdir $TMP_PENDRIVE_DIR
    mkdir $TMP_ROOT_DIR
}

function encrypt_disk_remote() {
    truncate -s 2M $2
    cryptsetup luksFormat $1 --header $2 --hash $3 --key-size $4 --cipher $5 --iter-time $6
}

function encrypt_disk() {
    cryptsetup luksFormat $1 --hash $2 --key-size $3 --cipher $4 --iter-time $5
}

function decrypt_disk_remote() {
    cryptsetup open --type luks --header $1 $2 $3
}

function decrypt_disk() {
    cryptsetup open --type luks $1 $2
}

function configure_disk_remote() {
    pvcreate $1
    vgcreate $(basename $1) $1
    lvcreate -L "$2"GB $(basename $1) -n swap
    lvcreate -l 100%FREE $(basename $1) -n root
    mkfs.ext4 $3 
    mount $3 $4
    mkswap $3 
    swapon $5
    mkfs.ext2 $6
    mount $6 $TMP_PENDRIVE_DIR/boot
}

function configure_disk() {
    mkfs.ext4 $1 
    mount $1 $TMP_ROOT_DIR
}

function install_arch() {
    pacstrap $TMP_ROOT_DIR $1
    genfstab -U $TMP_ROOT_DIR >> $TMP_ROOT_DIR/etc/fstab
    cp ./inside-chroot.sh $TMP_ROOT_DIR
    echo -e "\necho $2 > /etc/hostname" >> $TMP_ROOT_DIR/inside-chroot.sh
    arch-chroot $TMP_ROOT_DIR ./inside-chroot.sh
}

menu