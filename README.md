# Droidspaces Kernel Builder — Xiaomi 12X (psyche) / crDroid 12

用 GitHub Actions 从你 ROM 的内核源码出发,自动编出一个**带 Droidspaces 支持、且保留 KernelSU root** 的内核卡刷包。

> 背景与可行性分析见上级目录的 [psyche-droidspaces/README.md](../psyche-droidspaces/README.md)。
> 一句话:你这台机器原厂内核把 `CONFIG_PID_NS` 关掉了,容器起不来,必须自己编内核。

---

## 为什么这样设计(几个容易踩的坑,已经处理掉)

| 坑 | 处理方式 |
|---|---|
| **刷完丢 root** | 你 ROM 的 KSU **不在** `lineage-23.2` 分支里,而在**专门的 `lineage-23.2-ksu` 分支**(KernelSU 实体代码就在 `drivers/kernelsu/`,且已接好 `drivers/Makefile` 与 `drivers/Kconfig`)。工作流默认就用这个分支,并在构建前校验 `CONFIG_KSU=y`。 |
| 模块符号 CRC 不匹配 | 已核实该内核树 defconfig 里 `=m` 条目为 **0**,全部驱动编进内核,不产生 `.ko`。所以改内核配置不会让 `/vendor` 的模块加载失败。 |
| **dtb / dtbo 漂移** | 该设备 `BOARD_INCLUDE_DTB_IN_BOOTIMG := true`,dtb 在 boot.img 内。卡刷包**只替换 boot 里的 kernel,不放 dtb**,保留你 ROM 原有的 dtb 与 dtbo(顺带避开该内核自建 dtbo 的已知亮度闪烁问题)。 |
| 配置被 Kconfig 静默回滚 | 合并配置后先跑 `olddefconfig`,再**逐项校验**;启动关键项缺失就直接中止,不会让你刷到一个起不了容器的内核。 |
| 官方补丁没打 | 自动下载并预检(dry-run)官方两个 non-GKI 补丁,不匹配会立刻失败。 |
| 配置来源不靠谱 | `config/psyche-droidspaces.config` 来自**同 SoC(SM8250)、同内核版本(4.19.325)已跑通**的社区内核构建脚本,并对照 Droidspaces 官方 non-GKI 清单核对过。 |

---

## 前置条件

- 一个 GitHub 账号(仓库公开或私有都行)
- 手机:**已解锁 Bootloader**,ROM 自带 KernelSU root
- **务必备份你当前的 boot 分区**(回滚用):
  ```sh
  # root shell 里
  ls -l /dev/block/by-name/boot*
  dd if=/dev/block/by-name/boot_a of=/sdcard/boot-backup.img
  ```
  (A/B 设备两个槽都备份一下更稳;也可以直接用 ROM 卡刷包里的 `boot.img`)

---

## 一次性搭建

1. 在 GitHub 新建一个空仓库,例如 `droidspaces-psyche-kernel`,**不要**勾选任何模板。
2. 把本目录下的文件按下述结构推上去:

```
droidspaces-psyche-kernel/
├── .github/
│   └── workflows/
│       └── build.yml                      # 构建工作流
├── anykernel/
│   └── anykernel.sh                       # AnyKernel3 卡刷配置(psyche 专用)
├── config/
│   └── psyche-droidspaces.config          # Droidspaces 内核配置片段
└── README.md
```

```bash
git init
git add -A
git commit -m "Droidspaces kernel builder for psyche"
git branch -M main
git remote add origin https://github.com/<你的用户名>/droidspaces-psyche-kernel.git
git push -u origin main
```

---

## 运行构建

仓库页面 → **Actions** → 左侧 **Build Droidspaces Kernel (Xiaomi 12X / psyche)** → **Run workflow**:

| 输入 | 默认值 | 说明 |
|---|---|---|
| `kernel_repo` | `Rocky7842/android_kernel_xiaomi_sm8250` | 不用改 |
| `kernel_ref` | **`lineage-23.2-ksu`** | **不要改成 `lineage-23.2`,会丢 root**。也可填具体提交号(见下) |
| `publish_release` | `true` | 构建成功后发到 Releases,方便手机直接下载 |

首次构建约 **30–60 分钟**(编译 ~4.19 内核)。成功后 Releases 里会出现 `Droidspaces-psyche-<sha>.zip`。

---

## 关键:选对内核提交(避免内核与 ROM 的 dtb 不匹配)

工作流默认取 `lineage-23.2-ksu` 的**最新提交**。如果你 ROM 是几个月前编的,而分支之后改过 DTS,新内核配旧 dtb 有小概率不启动。

**稳妥做法**:把 `kernel_ref` 填成与你的 ROM 构建日期最接近的那个提交。

1. 手机上看 ROM 构建日期:`设置 → 关于手机 → 版本号`,例如 `crDroidAndroid-16.0-20260808-psyche-v12.11`。
2. 在 GitHub 上打开 `Rocky7842/android_kernel_xiaomi_sm8250` → 切到 `lineage-23.2-ksu` 分支 → **Commits**,按日期找到 2026-08-08 **当天或之前**的最后一个提交。
3. 复制它的完整 SHA,填进 `kernel_ref`。

本地找也行:

```bash
git clone --filter=blob:none -b lineage-23.2-ksu \
  https://github.com/Rocky7842/android_kernel_xiaomi_sm8250
cd android_kernel_xiaomi_sm8250
git log --before="2026-08-09" -1 --format="%H  %ci  %s"
```

> 先按默认(最新提交)试一次也没问题;万一开机异常,再用上面的方法换提交重编。

---

## 刷入

产出的 zip 是标准 AnyKernel3 卡刷包,**只改 boot 分区**。设备没有独立 recovery 分区,用以下任一方式:

- **KernelFlasher / EX Kernel Manager 等支持 AnyKernel3 的 App**(有 root 时最方便):选 zip → 刷入。
- **fastboot**:解出 zip 里的 `Image`,用你 ROM 的 `boot.img` 重新打包后 `fastboot flash boot new-boot.img`。

刷完**重启**。

---

## 刷完怎么验证

```sh
# 1) 内核版本变了 / 编译时间是你刚才
adb shell cat /proc/version

# 2) root 还在
adb shell su -c id        # 应返回 uid=0

# 3) 【最关键】命名空间已启用 —— 应该能看到 pid 和 ipc
adb shell su -c ls -l /proc/self/ns/
#   期望:mnt uts ipc net pid 都在
```

4. 装 **Droidspaces APK** → 授权 root → 让它安装后端 → 按提示重启 → **Settings → Requirements → Check Requirements**,全绿即成功。
5. 装容器:**Containers → + → Repository**,发行版选下面表里能跑的那些,存储**保持 Sparse Image**,网络用默认 **NAT**。

---

## 回滚

刷坏了就刷回备份的 boot:

```sh
fastboot flash boot boot-backup.img
```

只要能进 fastboot / bootloader 就一定能救回来。

---

## 已知限制:**只能用 systemd 258 之前的发行版**

你这台是 4.19.325 内核 + Android 16。该内核里:

- `clone3`(435) **已回移实现** ✅
- `openat2`(437) **不存在** ❌(已在 `fs/open.c`、`fs/namei.c` 中确认无实现)

systemd 258(2025-09)起同时依赖这两个且不再回退,所以:

| ✅ 能跑 | ❌ 跑不了 |
|---|---|
| Ubuntu 22.04 / 24.04、Debian 12 / 13、Alpine(OpenRC)、Void(runit)、OpenWrt(procd)、NixOS | Arch、Fedora、openSUSE 等 systemd ≥258 的滚动发行版 |

---

## 常见问题

| 现象 | 处理 |
|---|---|
| Actions 在"安装工具链"步骤失败 | 固定的 Clang 下载链接失效了。去 [ZyCromerZ/Clang releases](https://github.com/ZyCromerZ/Clang/releases) 复制新的 `.tar.gz` 链接,替换 `build.yml` 里那一行。 |
| "应用 Droidspaces 官方补丁" 预检失败 | 说明上游内核树结构变了。把 `kernel_ref` 换成更早的提交再试。 |
| 校验报 `CONFIG_PID_NS` 不是 `=y` | 说明配置片段没生效(拼接顺序问题)。检查 `config/psyche-droidspaces.config` 是否被正确追加、以及是否误改了 `cat` 的顺序。 |
| 校验报 `CONFIG_KSU` 未启用 | 你用了不带 KSU 的分支。`kernel_ref` 必须用 `lineage-23.2-ksu`。 |
| 刷完能开机但 root 没了 | 同上:用 `-ksu` 分支重编。 |
| 刷完卡开机动画 | 内核与 ROM 不匹配。换用"选对内核提交"里对应的提交重编,或直接回滚。 |
| 能开机、Droidspaces 里容器起不来 | 装 App 跑 **Check Requirements**,看它报哪一项缺;把报缺的项告诉我。 |

---

## 这个方案改动了什么(透明清单)

内核侧只做了三件事:

1. **追加配置**:`arch/arm64/configs/vendor/kona-perf_defconfig` 末尾追加 Droidspaces 配置片段,
   与 device tree 原本的 `kona-perf_defconfig` + `debugfs.config` + `sm8250-common.config` + `psyche.config`
   合并成一个 `psyche_ds_defconfig` 使用。核心是打开原本被**显式关闭**的 `CONFIG_PID_NS`,
   并补上 `SYSVIPC` / `POSIX_MQUEUE` / `IPC_NS`(前两者是 `IPC_NS` 的 Kconfig 前置)。
2. **打官方 non-GKI 补丁**。这里有个实测发现:
   - `02.fix_restore cgroup file prefix handling` → 目标是 `kernel/cgroup/cgroup.c`,**干净应用**(hunk 偏移 455 行)。
   - `01.fix_kernel_panic_in_xt_qtaguid` → 目标是 `net/netfilter/xt_qtaguid.c`,**该驱动在这棵树里已被移除**,
     补丁不适用。工作流会检测到目标缺失后**跳过并给出警告**,不会因此失败。
3. **编译后只取 `Image`** 打进 AnyKernel3,不动 dtb / dtbo / vendor_boot / vendor 分区。
