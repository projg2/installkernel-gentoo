FROM gentoo/stage3:amd64-systemd

RUN wget --progress=dot:mega -O - https://github.com/gentoo-mirror/gentoo/archive/master.tar.gz | tar -xz \
 && mv gentoo-master /var/db/repos/gentoo
RUN echo -e "ACCEPT_KEYWORDS=\"~amd64\"\nACCEPT_LICENSE=\"*\"\nFEATURES=\"-news -sandbox -usersandbox -cgroup binpkg-multi-instance -binpkg-docompress -binpkg-dostrip parallel-install -ipc-sandbox -network-sandbox -pid-sandbox binpkg-ignore-signature buildpkg getbinpkg\"\nMAKEOPTS=\"--jobs=$(nproc) --load-average=$(nproc)\"\nUSE=\"-initramfs kernel-install boot ukify -bash dash\"" >> /etc/portage/make.conf
RUN echo -e "sys-kernel/installkernel systemd -dracut -grub -systemd-boot -uki -ukify" >> /etc/portage/package.use/installkernel
RUN echo -e "sys-kernel/installkernel **" >> /etc/portage/package.accept_keywords/installkernel
RUN emerge --jobs="$(nproc)" --load-average="$(nproc)" sys-kernel/gentoo-kernel-bin app-text/tree app-text/asciidoc sys-apps/systemd sys-kernel/dracut sys-boot/grub sys-kernel/installkernel sys-fs/dosfstools sys-boot/refind app-alternatives/sh

CMD /tmp/installkernel-gentoo-9999/run_tests.sh
