#! /bin/bash

TMP_PENDRIVE_DIR="/mnt/pendrive"
TMP_ROOT_DIR="/mnt/root"

function menu() {
    configure_basic
    echo "Welcome to my arch install wizard"
    #available_diks=$(fdisk -l)
    NUMBER_LINE="$(lsblk | awk '/sd[a-z]/ { print }' | wc -l)"
    for (( i = 1; i <= $NUMBER_LINE; i++ )); do
        DISK="$(lsblk | grep sd | awk ' NR=='$i'{ print $1 }' )"
        SIZE="$(lsblk | grep sd | awk ' NR=='$i'{ print $4 }' )"
        MENU+="$DISK $SIZE "
    done
    disk=$(dialog --stdout --clear --backtitle "Arch Install wizard" --title "Choosing destination" --menu "Select the disk where you want to install arch" 0 0 0 $MENU)
    exitStatus=$?
    disk="/dev/"$disk
    dialog --stdout --title "Disk secure cleaning" --yesno "Do you want to fully delete the disk first?" 0 0
    exitStatus=$?
    if [ $exitStatus -eq 0 ]; then
        delete_times=$(dialog --stdout --title "Disk secure cleaning" --inputbox "How many times must the disk be deleted?" 0 0)
        clean_disk $delete_times $disk
    fi
    echo "Introduce the hostname:"
    read new_hostname
    generate_temp_dirs
    echo "Do you want to have the disk encrypted?[Y]"
    read disk_encrypted
    if [ "$disk_encrypted" == "Y" ]; then
        echo "Do you want to have a remote luks header?[Y]"
        read remote_headers
        echo "Introduce the cipher:[serpent-xts-plain64]"
        read cipher
        echo "Introduce the hash function:[sha512]"
        read hash
        echo "Introduce key-size:[512]"
        read key_size
        echo "Introduce iter-time:[3000]"
        read iter_time
        if [ "$remote_headers" == "Y" ]; then
            encrypt_disk_remote $disk /home/header.img $hash $key_size $cipher $iter_time
            decrypt_disk_remote /home/header.img /dev/sda enc
            configure_disk_remote /dev/mapper/enc 8 /dev/store/root $TMP_ROOT_DIR /dev/store/swap
        else
            encrypt_disk $disk $hash $key_size $cipher $iter_time
            decrypt_disk /dev/sda enc
        fi
    else
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
    pacman -Sy && pacman -S dialog --no-confirm
}

function clean_disk(){
    shred -v -n $1 $2 | while read -r line; do
        dialog --gauge "result" 0 0 "$line"
    done
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

function decrypt_disk() {
    cryptsetup open --type luks --header $1 $2 $3
}

function configure_disk_remote() {
    pvcreate $1 vgcreate $1 lvcreate -L "$2"GB store -n swap lvcreate -l 100%FREE store -n root
    mkfs.ext4 $3 
    mount $3 $4
    mkswap $3 
    swapon $5
    parted $
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