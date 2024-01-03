#!/bin/bash

# 安裝vim
sudo apt update
sudo apt install -y vim

echo "Choice the CPU:"
echo "1. Intel"
echo "2. AMD"
echo "3. Xeon"
read -p "Please enter number: " cpu_choice

case $cpu_choice in
    1)
        # Intel CPU
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"/' /etc/default/grub
        ;;
    2)
        # AMD CPU
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"/' /etc/default/grub
        ;;
    3)
        # Xeon CPU
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet"/GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off"/' /etc/default/grub
        ;;
    *)
        echo "無效的選擇，請選擇1、2或3。"
        exit 1
        ;;
esac
update-grub

echo "GRUB setting is update"

echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf

echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf

lspci -v | grep -E "VGA compatible controller|Audio device"

read -p "Enter the Device number (ex: 01:00): " device
lspci_output=$(lspci -n -s "$device")

echo "Output the content:"
echo "$lspci_output"

read -p "Enter the Device ID(ex: 10de:1382,10de:0fbc,XXX:OOO....)" device_id

echo "options vfio-pci ids="$device_id" disable_vga=1"> /etc/modprobe.d/vfio.conf

update-initramfs -u
reboot