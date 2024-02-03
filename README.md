# installkernel-gentoo

Install the kernel on a Gentoo Linux system.

This script is called by the kernel's `make install` if it is installed as
`/sbin/installkernel`. It is also called by `kernel-install.eclass`.

This script was extracted from `sys-apps/debianutils`. It was subsequenly modified
for Gentoo by Michał Górny and Andrew Ammerlaan.

See the [installkernel Gentoo wiki page](https://wiki.gentoo.org/wiki/Installkernel) for more details.

## Making changes

When making changes:
- Adjust the `installkernel-9999.ebuild` in this repository if changes to the `::gentoo` ebuild are intended, then
- Run tests with `./run_tests_in_docker.sh` (installing Docker is required).

Do NOT run `./run_tests.sh` outside of any containers, it WILL mess with the systems `/boot` and `/efi`.
