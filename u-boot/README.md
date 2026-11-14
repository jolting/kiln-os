# U-Boot for the AD5X (work in progress)

Mainline U-Boot (v2026.10) with the Ingenic X2600 and the Adventurer 5X:
U-Boot proper only, linked at 0x80100000. It relies on the boot ROM's SPL
(Flashforge's) having set up the clocks and the DDR, as the SPL does
before it loads a kernel. Not part of any image yet; nothing installs it.

`build.sh` fetches the release, applies `patches/` (`git format-patch`
output, upstream style) and builds `u-boot.bin` with Buildroot's toolchain.

## What it does

| Part | State |
|---|---|
| Console | UART0 on the DEBUG header, 115200 8N1 (fractional baud registers reset) |
| Timer | The global OST, 64-bit at 24 MHz (the CP0 counter doesn't run) |
| RAM | The 236 MiB below `rmem` and the RISC-V co-processor's region |
| eMMC | MSC0, Synopsys DWC MSHC (SDHCI), card clock from the CGU; PIO, 4-bit, 50 MHz |
| Boot | `sqfsload` of `/usr/lib/ad5x/kernel66/xImage` from `rootfs2` (LZO SquashFS), `bootm` |
| Environment | eMMC user area, 0x8A400 and 0x92400 (two copies, 32 KiB each), where stock's U-Boot would keep it; reset to this build's defaults when it comes from another build, keeping `boot_pending` |
| Boot flag | `ad5x_flag [a\|b]`: reads or sets the `ota` sector (LBA 0x6C800) the SPL boots by |
| Fallback | Each start sets `boot_pending` and boots the main OS. If it's still set at the next start, or the kernel can't be loaded, U-Boot sets the flag to slot A and boots the recovery OS's kernel the way the SPL would. Linux would clear `boot_pending` (`fw_setenv`) once start-up completes; Kiln doesn't yet |

Not done: watchdog reset (`reset`), eMMC DMA and 8-bit bus, Ethernet, USB.

## Tested (2026-11-14, by chainload; no slot or first-MiB writes)

From the stock 5.10 kernel with `kernel-ingenic66/chainload`, its
trampoline's `LOAD_ADDR` changed to 0x80100000, after setting PE9/PE10
(the DEBUG header) to UART0:

- the prompt, `time sleep 10` = 10.000 s;
- `mmc info` (SanDisk `DA2016`, 52 MHz High Speed mode at 50 MHz), `mmc part`, the `ota` and `kernel2` sectors;
- a direct boot of 6.6 from `rootfs2` (5.6 MiB in about 0.3 s), up to the main OS with Klipper ready;
- `saveenv`: a dump of the first MiB before and after differs only in 0x8A400-0x9274B, both copies with valid CRCs;
- a start with `boot_pending` set: flag set to slot A, the stock kernel loaded from `kernel` (checksum checked) and the recovery OS up.

## Plan

Program it through the X2600's USB boot mode on J28, the mainboard's OTG
port (`docs/boot-slots.md`, "J28"), rather than by writing a kernel slot
from Linux first. The boot ROM's USB mode is also the way back from a boot
loader that hangs. Open: forcing USB mode while a valid SPL is on the
eMMC (K4, held through power-on, untested).

Writing the boot loader can make the printer unable to start until it is
reprogrammed over J28. Don't install it on a printer you can't open.
