#! /bin/bash
hwclock --systohc --utc
echo LANG=es > /etc/locale.conf
echo keymap=es > /etc/vconsole.conf