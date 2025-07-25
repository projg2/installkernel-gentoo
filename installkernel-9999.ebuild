# Copyright 2019-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit eapi9-ver linux-info

DESCRIPTION="Gentoo fork of installkernel script from debianutils"
HOMEPAGE="
	https://github.com/projg2/installkernel-gentoo
	https://wiki.gentoo.org/wiki/Installkernel
"
SRC_URI="https://github.com/projg2/installkernel-gentoo/archive/v${PV}.tar.gz
	-> ${P}.tar.gz"
S="${WORKDIR}/${PN}-gentoo-${PV}"

LICENSE="GPL-2+"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~loong ~m68k ~mips ~ppc ~ppc64 ~riscv ~s390 ~sparc ~x86 ~amd64-linux ~x86-linux"
IUSE="dracut efistub grub refind systemd systemd-boot ugrd uki ukify"
REQUIRED_USE="
	systemd-boot? ( systemd )
	ukify? ( uki )
	?? ( dracut ugrd )
"
# systemd-boot could be made to work without the systemd flag, but this
# makes no sense since in systemd(-utils) the boot flag already
# requires the kernel-install flag.
#
# Ukify hooks do nothing if the layout is not uki, so force this here.
#
# Only one initramfs generator flag can be selected. Note that while
# both dracut and ukify are UKI generators we don't block those because
# enabling both results in building an initramfs only with dracut and
# building an UKI with ukify, which is a valid configuration.

RDEPEND="
	!<=sys-kernel/installkernel-systemd-3
	dracut? (
		>=sys-kernel/dracut-106
		uki? (
			|| (
				sys-apps/systemd[boot(-)]
				sys-apps/systemd-utils[boot(-)]
			)
		)
	)
	efistub? (
		systemd? ( >=app-emulation/virt-firmware-24.7 )
		!systemd? ( sys-boot/uefi-mkconfig )
	)
	grub? ( sys-boot/grub )
	refind? ( sys-boot/refind )
	systemd? (
		|| (
			>=sys-apps/systemd-255[kernel-install(-)]
			>=sys-apps/systemd-utils-255[kernel-install(-)]
		)
	)
	systemd-boot? (
		|| (
			sys-apps/systemd[boot(-)]
			sys-apps/systemd-utils[boot(-)]
		)
	)
	ukify? (
		|| (
			sys-apps/systemd[boot(-),ukify(-)]
			sys-apps/systemd-utils[boot(-),ukify(-)]
		)
	)
	ugrd? ( >=sys-kernel/ugrd-1.31.2 )
	!=sys-apps/systemd-255.2-r1
	!=sys-apps/systemd-255.2-r0
	!~sys-apps/systemd-255.1
	!~sys-apps/systemd-255.0
	!=sys-apps/systemd-254.8-r0
	!=sys-apps/systemd-254.7-r0
	!~sys-apps/systemd-254.6
	!<=sys-apps/systemd-254.5-r1
" # Block against systemd that still installs dummy install.conf

pkg_setup() {
	use efistub && CONFIG_CHECK="~EFI_STUB" linux-info_pkg_setup
}

src_install() {
	keepdir /etc/kernel/install.d
	keepdir /etc/kernel/preinst.d
	keepdir /etc/kernel/postinst.d
	keepdir /usr/lib/kernel/install.d
	keepdir /usr/lib/kernel/preinst.d
	keepdir /usr/lib/kernel/postinst.d

	exeinto /usr/lib/kernel/preinst.d
	doexe hooks/99-check-diskspace.install
	use dracut && doexe hooks/52-dracut.install
	use ukify && doexe hooks/60-ukify.install

	exeinto /usr/lib/kernel/postinst.d
	doexe hooks/99-write-log.install
	use grub && doexe hooks/91-grub-mkconfig.install
	use efistub && doexe hooks/95-efistub-uefi-mkconfig.install
	use refind && doexe hooks/95-refind-copy-icon.install

	exeinto /usr/lib/kernel/install.d
	doexe hooks/systemd/00-00machineid-directory.install
	doexe hooks/systemd/10-copy-prebuilt.install
	doexe hooks/systemd/85-check-diskspace.install
	doexe hooks/systemd/90-compat.install
	doexe hooks/systemd/90-zz-update-static.install
	doexe hooks/systemd/99-write-log.install
	use dracut && doexe hooks/systemd/52-dracut.install
	use grub && doexe hooks/systemd/91-grub-mkconfig.install
	use efistub && doexe hooks/systemd/95-efistub-kernel-bootcfg.install
	use refind && doexe hooks/systemd/95-refind-copy-icon.install

	if use grub && use uki; then
		exeinto /etc/grub.d
		doexe grub/05_uki
	fi

	if use systemd; then
		sed -e 's/${SYSTEMD_KERNEL_INSTALL:=0}/${SYSTEMD_KERNEL_INSTALL:=1}/g' -i installkernel ||
			die "enabling systemd's kernel-install failed"
	fi

	# set some default config using the flags we have anyway
	touch "${T}/install.conf" || die
	echo "# This file is managed by ${CATEGORY}/${PN}" >> "${T}/install.conf" || die
	if use uki; then
		echo "layout=uki" >> "${T}/install.conf" || die
	elif use efistub; then
		echo "layout=efistub" >> "${T}/install.conf" || die
	elif use grub; then
		echo "layout=grub" >> "${T}/install.conf" || die
	elif use systemd-boot; then
		echo "layout=bls" >> "${T}/install.conf" || die
	else
		echo "layout=compat" >> "${T}/install.conf" || die
	fi

	if use dracut; then
		echo "initrd_generator=dracut" >> "${T}/install.conf" || die
		if ! use ukify; then
			if use uki; then
				echo "uki_generator=dracut" >> "${T}/install.conf" || die
			else
				echo "uki_generator=none" >> "${T}/install.conf" || die
			fi
		fi
	elif use ugrd; then
		echo "initrd_generator=ugrd" >> "${T}/install.conf" || die
	else
		echo "initrd_generator=none" >> "${T}/install.conf" || die
	fi

	if use ukify; then
		echo "uki_generator=ukify" >> "${T}/install.conf" || die
	else
		if ! use dracut; then
			echo "uki_generator=none" >> "${T}/install.conf" || die
		fi
	fi

	insinto /usr/lib/kernel
	doins "${T}/install.conf"

	insinto /etc/logrotate.d
	newins installkernel.logrotate installkernel
	keepdir /var/lib/misc

	into /
	dosbin installkernel
	doman installkernel.8

	einstalldocs
}

pkg_postinst() {
	# show only when upgrading to 14+
	if ver_replacing -lt 14; then
		elog "Version 14 and up of ${PN} effectively merges"
		elog "${PN}-gentoo and ${PN}-systemd."
		elog "Switching between the traditional installkernel and systemd's"
		elog "kernel-install is controlled with the systemd USE flag or the"
		elog "SYSTEMD_KERNEL_INSTALL environment variable."
		elog
		elog "See the installkernel wiki page[1] for more details."
		elog
		elog "[1]: https://wiki.gentoo.org/wiki/Installkernel"
		elog
	fi

	# show only on first install of version 20+
	if [[ -z "${REPLACING_VERSIONS}" ]] || ver_replacing -lt 20; then
		if has_version "sys-boot/grub" && ! use grub; then
			elog "sys-boot/grub is installed but the grub USE flag is not enabled."
			elog "Users may want to enable this flag to automatically update the"
			elog "bootloader configuration on each kernel install."
		fi
		if ( has_version "sys-apps/systemd[boot]" ||
			has_version "sys-apps/systemd-utils[boot]" ) &&
			! use systemd-boot; then
				elog "systemd-boot is installed but the systemd-boot USE flag"
				elog "is not enabled. Users should enable this flag to install kernels"
				elog "in a layout that systemd-boot understands and to automatically"
				elog "update systemd-boot's configuration on each kernel install."
		fi
	fi

	if use efistub; then
		ewarn "Automated EFI Stub booting is highly experimental. UEFI implementations"
		ewarn "often differ between vendors and as a result EFI stub booting is not"
		ewarn "guaranteed to work for all UEFI systems. Ensure an alternative method"
		ewarn "of booting the system is available before rebooting."
	fi

	# Initialize log file if there is none
	dodir /var/log
	local log=${ROOT}/var/log/installkernel.log
	if [[ ! -s ${log} ]]; then
		echo -e \
"DATE\t"\
"KI_VENDOR\t"\
"VERSION\t"\
"CONF_ROOT\t"\
"LAYOUT\t"\
"INITRD_GEN\t"\
"UKI_GEN\t"\
"BOOT_ROOT\t"\
"KERNEL_REL_PATH\t"\
"INITRD_REL_PATH\t"\
"PLUGIN_OVERRIDE\t"\
>> "${log}" || die
	fi
}
