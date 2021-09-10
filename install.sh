#! /bin/zsh

TMP_PENDRIVE_DIR="/mnt/pendrive"
TMP_ROOT_DIR="/mnt/root"

function menu() {
    configure_basic
    echo "Welcome to my arch install wizard"
    available_diks=$(fdisk -l)
    echo $available_diks
    echo -e "\nFirst select the disk where you want to install arch:[/dev/sda]"
    read disk
    echo "Do you want to fully delete the disk first?[N]"
    read delete
    if [ "$delete" == "Y" ]; then
        echo "How many times must the disk be deleted?[3]"
        read delete_times
        clean_disk $delete_times $disk
    fi
    echo "Do you want to have the disk encrypted?[Y]"
    read disk_encrypted
    if [ "$disk_encrypted" == "Y" ]; then
        echo "Do you want to have a remote luks header?[Y]"
        read remote_luks
        echo "Introduce the cipher:[serpent-xts-plain64]"
        read cipher
        echo "Introduce the hash function:[sha512]"
        read hash
        echo "Introduce key-size:[512]"
        read key_size
        echo "Introduce iter-time:[3000]"
        read iter_time
        encrypt_disk $disk /home/header.img $hash $key_size $cipher $iter_time

    
        
    fi
    
        
}    

function configure_basic() {
    loadkeys es
    timedatectl set ntp-true
}

function clean_disk(){
    shred -n $1 $2
}

function generate_temp_dirs() {
    mkdir $TMP_PENDRIVE_DIR
    mkdir $TMP_ROOT_DIR
}

function encrypt_disk() {
    truncate -s 2M $2
    cryptsetup luksFormat $1 --header $2 --hash $3 --key-size $4 --cipher $5 --iter-time $6
}

function decrypt_disk() {
    cryptsetup open --type luks --header $1 $2 $3
}

function configure_disk() {
    pvcreate $1 vgcreate $1 lvcreate -L "$2"GB store -n swap lvcreate -l 100%FREE store -n root
    mkfs.ext4 $3 mount $3 $4 mkswap $3 swapon $5
    #parted <---- esto falta buscar como hacerlo no interactivo
    #mount $6 $TMP_PENDRIVE_DIR/boot
}

function install_arch() {
    pacstrap $1 $2
    genfstab -U $TMP_ROOT_DIR >> $TMP_ROOT_DIR/etc/fstab
    arch-chroot $TMP_ROOT_DIR
    hwclock --systohc --utc
    echo LANG=es > /etc/locale.conf
    echo keymap=es > /etc/vconsole.conf
    echo $3 > /etc/hostname
}

#menu
generate_temp_dirs
encrypt_disk /dev/sda /home/header.img sha512 512 serpent-xts-plain64 3000
decrypt_disk /home/header.img /dev/sda enc
configure_disk /dev/mapper/enc 8 /dev/store/root /mnt/root /dev/store/swap