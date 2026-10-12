### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Xiaomi 12X (psyche) — Droidspaces kernel

### AnyKernel setup
# global properties
properties() { '
kernel.string=Droidspaces Kernel for Xiaomi 12X (psyche)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=psyche
device.name2=
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
# BLOCK 用分区名而非绝对路径:ak3-core.sh 的 setup_ak() 会自动解析
#   /dev/block/mapper、/dev/block/by-name、/dev/block/bootdevice/by-name
# 并叠加当前槽位后缀(_a/_b)。psyche 无独立 recovery 分区,内核在 boot。
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
# 只 dump/repack boot:替换其中的 kernel(Image),ramdisk 与 dtb 段保持 ROM 原样。
# 包内不放 dtb / dtbo,因此不会触发 ak3-core.sh 的 vendor_boot 自动分支。
dump_boot;
write_boot;
## end boot install
