# ProxmoxVE VM Device Passthrough Guide

## setup.1
Searching for the installation method of PVE online, there are many resources available that can be utilized. I won't go into detail here. However, here are some important notes for the installation:

- The installation mode must use UEFI, and you need to enable it in the BIOS.

- You cannot have both the iGPU and dGPU enabled simultaneously. You must disable the CPU's iGPU, as having both active can lead to issues.

## setup.2
Open the PVE dashboard, and log in using the IP address, which may be in the format `192.168.xxx.ooo:8006`, specific to your installation. The default login is with the root username and the password you set during the installation. After logging in, you can access the `shell` at the following location
![](https://hackmd.io/_uploads/By8D6mSfp.png)

## setup.3
### PCI Passthrough Configuration on Proxmox VE
Begin entering the following commands

- **Install the Vim text editor**
 ```sh=
 apt install vim
 ```
- **Edit /etc/default/grub**
```sh=
vim /etc/default/grub
```
> Find the following content:
```sh=
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
```
> Then modify the settings as follows:
- `For Intel CPUs:`
```sh=
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```
- `For AMD CPUs:`
```sh=
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"
```
- `For Xeon CPUs, it is recommended to add the following settings:`
```sh=
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt pcie_acs_override=downstream,multifunction nofb nomodeset video=vesafb:off,efifb:off"
```
> Update the grub boot parameters:
```sh=
update-grub
```
- `Output the content:`
```bash=
root@pve:~# update-grub
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.2.16-3-pve
Found initrd image: /boot/initrd.img-6.2.16-3-pve
Found memtest86+ 64bit EFI image: /boot/memtest86+x64.efi
Adding boot menu entry for UEFI Firmware Settings ...
done
```
- **Edit /etc/modules**
```sh=
vim /etc/modules
```
> Then enter the following content:
```sh=
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```
> As shown in the image
![](https://hackmd.io/_uploads/SyY0UGBz6.png)
- **Modify the IOMMU interrupt remapping table**
> Enter the following content to make IOMMU and VFIO work correctly
```sh=
echo "options vfio_iommu_type1 allow_unsafe_interrupts=1" > /etc/modprobe.d/iommu_unsafe_interrupts.conf
echo "options kvm ignore_msrs=1" > /etc/modprobe.d/kvm.conf
```
- **Disable unnecessary drivers**
```sh=
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
```
- **Assign the GPU to VFIO**
```sh=
lspci -v
```
> Next, you should see a list of many PCI devices, and some of these lines may be related to the GPU, with a key term possibly being **`VGA compatible controller`**
- `Output the content:`
```bash=
01:00.0 VGA compatible controller: NVIDIA Corporation GM107 [GeForce GTX 745] (rev a2) (prog-if 00 [VGA controller])
        Subsystem: Micro-Star International Co., Ltd. [MSI] GM107 [GeForce GTX 745]
        Flags: bus master, fast devsel, latency 0, IRQ 55
        Memory at d2000000 (32-bit, non-prefetchable) [size=16M]
        Memory at c0000000 (64-bit, prefetchable) [size=256M]
        Memory at d0000000 (64-bit, prefetchable) [size=32M]
        I/O ports at e000 [size=128]
        Expansion ROM at d3000000 [disabled] [size=512K]
        Capabilities: [60] Power Management version 3
        Capabilities: [68] MSI: Enable+ Count=1/1 Maskable- 64bit+
        Capabilities: [78] Express Legacy Endpoint, MSI 00
        Capabilities: [100] Virtual Channel
        Capabilities: [250] Latency Tolerance Reporting
        Capabilities: [258] L1 PM Substates
        Capabilities: [128] Power Budgeting <?>
        Capabilities: [600] Vendor Specific Information: ID=0001 Rev=1 Len=024 <?>
        Capabilities: [900] Secondary PCI Express
        Kernel driver in use: nouveau
        Kernel modules: nvidiafb, nouveau

01:00.1 Audio device: NVIDIA Corporation GM107 High Definition Audio Controller [GeForce 940MX] (rev a1)
        Subsystem: Micro-Star International Co., Ltd. [MSI] GM107 High Definition Audio Controller [GeForce 940MX]
        Flags: bus master, fast devsel, latency 0, IRQ 17
        Memory at d3080000 (32-bit, non-prefetchable) [size=16K]
        Capabilities: [60] Power Management version 3
        Capabilities: [68] MSI: Enable- Count=1/1 Maskable- 64bit+
        Capabilities: [78] Express Endpoint, MSI 00
        Kernel driver in use: snd_hda_intel
        Kernel modules: snd_hda_intel
```
> Insert the values (XX:00) from the previous step and execute the following command to find the Vendor ID and Device ID for the GPU and Audio:
```sh=
lspci -n -s 01:00
```
- `Output the content:`
```bash=
01:00.0 0300: 10de:1382 (rev a2)
01:00.1 0403: 10de:0fbc (rev a1)
```
> 01:00.0 0300: 10de:1382 (rev a2) <— Video controller
> 01:00.1 0403: 10de:0fbc (rev a1) <— Audio controller
> 
> The VID/PID is represented as xxxx:oooo. Enter the following command to map this information to VFIO, and replace the 'ids' within the command with the VID/PID you obtained earlier, such as `ids=10de:1382,10de:1382`:
```sh=
echo "options vfio-pci ids=10de:1382,10de:1382 disable_vga=1"> /etc/modprobe.d/vfio.conf
```
> Update the services and then restart:
```sh=
update-initramfs -u
reboot
```
- `Output the content:`
```bash=
root@pve:~# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.2.16-3-pve
Running hook script 'zz-proxmox-boot'..
Re-executing '/etc/kernel/postinst.d/zz-proxmox-boot' in new private mount namespace..
No /etc/kernel/proxmox-boot-uuids found, skipping ESP sync.
```

## setup.4
### Create a VM on Proxmox VE
- **Upload the ISO file**
> - Choose `upload` to upload from your local machine or select `Download from URL` to download from a URL:
> ![](https://hackmd.io/_uploads/HkAElVSzT.png)
- **Create a VM, using Ubuntu as an example**
> - Click `Create VM` in the upper right corner of the screen
> ![](https://hackmd.io/_uploads/r1K4QyIG6.png)
> - After entering the VM name in the `Name` field, click `Next`:
> ![](https://hackmd.io/_uploads/S1GeKJIGT.png)
> - After selecting the ISO file in the `ISO image` section, click `Next`:
> ![](https://hackmd.io/_uploads/Sk4Rc1IG6.png)
> - Select `q35` for the Machine, choose `UEFI` for the BIOS, specify the EFI partition location, and then check the box for `Qemu Agent`. Afterward, click `Next`:
> ![](https://hackmd.io/_uploads/ryv2C1LGa.png)
> - You can adjust the capacity in the `Disk size`, choose whether or not to enable `SSD emulation`, and then click `Next`:
> ![](https://hackmd.io/_uploads/By0LxeIGp.png)
> - You should adjust the number of `Core`, and it's recommended to use a value greater than or equal to 2. Then, click `Next`:
> ![](https://hackmd.io/_uploads/SJ_tZlUMT.png)
> - You should adjust the `Memory` size, and it's recommended to set it to a value greater than or equal to 2048. Then, click `Next`:
> ![](https://hackmd.io/_uploads/B1ezMxIG6.png)
> - Disable the `Firewall` and then click `Next`:
> ![](https://hackmd.io/_uploads/HJMofgIGT.png)
> - Check for any configuration errors, and if everything looks correct, click `Finish`:
> ![](https://hackmd.io/_uploads/ryEpmgIM6.png)
> - Go to `Datacenter > pve > Your VM and click` on `Hardware Device`:
> ![](https://hackmd.io/_uploads/HJLJ8eLMp.png)
> - Click on the `Raw Device` option and select the graphics card, but do not select the Audio Controller:
> ![](https://hackmd.io/_uploads/SJgsxhwGa.png)
> - Check `All Functions` to enable all device functions, and then check `PCI-Express`:
> ![](https://hackmd.io/_uploads/Sy6Bz2wfT.png)
> - Afterward, click `Start` in the upper right corner, and then click `Console` to open the noVNC display:
> ![](https://hackmd.io/_uploads/BkWtxs0M6.png)
> - Next, proceed with the `Ubuntu` installation:
> ![](https://hackmd.io/_uploads/ryfN533MT.png)
> - After the installation is complete, open the `Terminal`:
> ![](https://hackmd.io/_uploads/rJ6Fhhnza.png)

## setup.5
### Begin installing the drivers
- **Fetch the drivers**
```sh=
apt update
apt upgrade
apt purge *nvidia*
```
- **Next, enter `ubuntu-drivers list`, and you will see the following content**
```sh=
ubuntu-drivers list
```
> ![](https://hackmd.io/_uploads/r1anTh2Ma.png)
- **Install the drivers**
> Let Ubuntu automatically choose the recommended driver version:
```sh=
ubuntu-drivers autoinstall
```
> Manually specify the version by entering the driver version you want to install:
```sh=
apt install nvidia-driver-"Version"
```
- **Then, restart the system**
```sh=
reboot
```
- **Enter the following command to confirm if the installation was successful; the driver section should display `nvidia`**
```sh=
sudo lshw -C display
```
> ![](https://hackmd.io/_uploads/S1Rg4ThMa.png)
- **Enter the following command to output detailed information**
```sh=
nvidia-smi
```
> ![](https://hackmd.io/_uploads/B1kLNT2GT.png)
- **You can also check if the driver installation was successful under the system information section**
> ![](https://hackmd.io/_uploads/BJw04phzp.png)

## setup.6
### The effect of GPU passthrough
You can plug VGA or other monitor cables directly into the graphics card, and the virtual machine's display can be shown on the screen. However, you must make the following configuration settings:
- **Add USB devices**
> - Select `USB Device` in the `Add` menu
> ![](https://hackmd.io/_uploads/BysMn9CMT.png)
- **Select the keyboard and mouse devices**
> - Select the keyboard and mouse devices under `Use USB Vendor/Device ID`
> ![](https://hackmd.io/_uploads/SJcEac0z6.png)
- **Turn off the noVNC display**
> - Double-click on the `Display` item to start editing
> ![](https://hackmd.io/_uploads/rkUZC9CGa.png)
> - Choose `none` for the `Graphics card` item
> ![](https://hackmd.io/_uploads/SkR_RcCz6.png)
- **Start the virtual machine**
> - Connect the monitor to the graphics card, open the virtual machine in the dashboard, and you will see the boot screen on the monitor. At this point, you won't be able to access the display through the Console to view it via noVNC
> ![](https://hackmd.io/_uploads/rJi0Zs0MT.png)

## setup.7 
### You can use automated scripts to accomplish passthrough
```sh=
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ParrotXray/ProxmoxVE-VM-Device-Passthrough-Guide/refs/heads/main/AutoGPU.sh)"
```




