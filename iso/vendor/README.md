# Meegeleverde broncode

## grub-btrfs 4.14

- **Bron:** https://github.com/Antynea/grub-btrfs/releases/tag/v4.14
- **Tarball:** `https://github.com/Antynea/grub-btrfs/archive/refs/tags/v4.14.tar.gz`
- **SHA256:** `4fe2f8a49b39e3e561fc51bbc5a0f81a7222c1e9ef8672e014e0ba3bedad20c6`
- **Licentie:** GPL-3.0 (zie `LICENSE` in de tarball)

Debian levert geen `grub-btrfs`-pakket. De ISO bouwt de bron daarom tijdens
de live-build in de chroot en neemt het resultaat mee in de squashfs. Zo
komen de momentopnamen ook in het GRUB-menu van het geïnstalleerde systeem.

De tarball wordt niet gewijzigd; `iso/build.sh` controleert de sha256 en
`iso/live-build/config/hooks/live/0400-grub-btrfs.hook.chroot` installeert
hem met `make install`.
