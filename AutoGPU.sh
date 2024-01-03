#!/bin/bash

# 安裝vim
sudo apt update
sudo apt install -y vim

# 讀取用戶的CPU選擇
echo "Choice the CPU:"
echo "1. Intel"
echo "2. AMD"
echo "3. Xeon"
read -p "Please enter number: " cpu_choice

# 根據用戶的選擇修改GRUB設定
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

# 更新GRUB
update-grub

echo "GRUB setting is update"

echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf

echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf

lspci -v | grep -E "VGA compatible controller|Audio device"

# 詢問使用者輸入裝置編號
read -p "請輸入裝置編號格式：域:總線:裝置.函數，例如 01:00: " device_id
lspci_output=$(lspci -n -s "$device_id")

echo "Output the content:"
echo "$lspci_output"

# 提取 Vendor ID 和 Device ID
device_info=$(echo "$lspci_output" | awk '{print $3}')
echo ""
echo "Device 1: $device_info"

device_info=$(echo "$lspci_output" | awk '{print $4}')
echo "Device 2: $device_info"
