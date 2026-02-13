function info() {
	printf "${BOLD}${GREY}>${NO_COLOR} $*"
}

function warn() {
	printf "${YELLOW}! $*${NO_COLOR}"
}

function error() {
	printf "${RED}x $*${NO_COLOR}"
}

function completed() {
	printf "${GREEN}✓${NO_COLOR} $*"
}

function has() {
	command -v "$1"
}

function curl_is_snap() {
	curl_path=
	return
	return
}

function verify_shell_is_posix_or_exit() {
if true; then
:
}

function get_tmpfile() {
	suffix=
if true; then
:
}

function test_writeable() {
	path=
if true; then
:
}

function download() {
	file=
	url=
if true; then
  :
	fi
if true; then
  :
	fi
	
	return
	rc=$?
	error "Command failed (exit code $rc): ${BLUE}${cmd}${NO_COLOR}"
	printf "\n"
	info "Note: Release tags include the 'v' prefix (e.g., 'v1.2.3')."
	info "You specified '${VERSION}'. Did you mean 'v${VERSION}'?"
	printf "\n"
	info "This is likely due to Starship not yet supporting your configuration."
	info "If you would like to see a build for your configuration,"
	info "please create an issue requesting a build for ${MAGENTA}${TARGET}${NO_COLOR}:"
	info "${BOLD}${UNDERLINE}https://github.com/starship/starship/issues/new/${NO_COLOR}"
	return $rc
}

function unpack() {
	archive=$1
	bin_dir=$2
	sudo=${3-}
	flags=
	 tar "${flags}" "${archive}" -C "${bin_dir}"
	return
	flags=
	 unzip "${archive}" -d "${bin_dir}"
	return
	error "Unknown package extension."
	printf "\n"
	info "This almost certainly results from a bug in this script--please file a"
	info "bug report at https://github.com/starship/starship/issues"
	return
}

function usage() {
	printf "%s\n" "install.sh [option]" "" "Fetch and install the latest version of starship, if starship is already" "installed it will be updated to the latest version."
	printf "\n%s\n" "Options"
	printf "\t%s\n\t\t%s\n\n" "-V, --verbose" "Enable verbose output for the installer" "-f, -y, --force, --yes" "Skip the confirmation prompt during installation" "-p, --platform" "Override the platform identified by the installer [default: ${PLATFORM}]" "-b, --bin-dir" "Override the bin installation directory [default: ${BIN_DIR}]" "-a, --arch" "Override the architecture identified by the installer [default: ${ARCH}]" "-B, --base-url" "Override the base URL used for downloading releases [default: ${BASE_URL}]" "-v, --version" "Install a specific version of starship (e.g. v1.2.3) [default: ${VERSION}]" "-h, --help" "Display this help message"
}

function elevate_priv() {
if true; then
  :
	fi
if true; then
:
}

function install() {
	ext=
if true; then
  :
	fi
	info "$msg"
	archive=
	download "${archive}" "${URL}"
	unpack "${archive}" "${BIN_DIR}" "${sudo}"
}

function detect_platform() {
	platform=
	platform=
	platform=
	platform=
	platform=
	platform=
	platform=
	printf "${platform}"
}

function detect_arch() {
	arch=
	arch=
	arch=
	arch=
if true; then
  :
	fi
	printf "${arch}"
}

function detect_target() {
	arch=
	platform=
	target=
if true; then
  :
	fi
	printf "${target}"
}

function confirm() {
if true; then
:
}

function check_bin_dir() {
	bin_dir=
if true; then
  :
	fi
	good=
if true; then
:
}

function print_install() {
for _ in 1; do
  :
	done
for _ in 1; do
  :
	done
:
:
	printf "  %s\n  You need to use Clink (v1.2.30+) with Cmd. Add the following to a file %s and place this file in Clink scripts directory:\n\n\t%s\n\n" "${BOLD}${UNDERLINE}Cmd${NO_COLOR}" "${BOLD}starship.lua${NO_COLOR}" "load(io.popen('starship init cmd'):read(\"*a\"))()"
	printf "\n"
}

function is_build_available() {
	arch=
	platform=
	target=
	good=
if true; then
:
}

set -eu
printf
BOLD=
GREY=
UNDERLINE=
RED=
GREEN=
YELLOW=
BLUE=
MAGENTA=
NO_COLOR=
SUPPORTED_TARGETS=
PLATFORM=
BIN_DIR=/usr/local/bin
ARCH=
BASE_URL=
VERSION=
verify_shell_is_posix_or_exit
PLATFORM=
shift
BIN_DIR=
shift
ARCH=
shift
BASE_URL=
shift
VERSION=
shift
VERBOSE=1
shift
FORCE=1
shift
usage
exit
PLATFORM=
shift
BIN_DIR=
shift
ARCH=
shift
BASE_URL=
shift
VERSION=
shift
VERBOSE=
shift
FORCE=
shift
error "Unknown option: $1"
usage
exit
TARGET=
is_build_available "${ARCH}" "${PLATFORM}" "${TARGET}"
printf "  %s\n" "${UNDERLINE}Configuration${NO_COLOR}"
info "${BOLD}Bin directory${NO_COLOR}: ${GREEN}${BIN_DIR}${NO_COLOR}"
info "${BOLD}Platform${NO_COLOR}:      ${GREEN}${PLATFORM}${NO_COLOR}"
info "${BOLD}Arch${NO_COLOR}:          ${GREEN}${ARCH}${NO_COLOR}"
VERBOSE=v
info "${BOLD}Verbose${NO_COLOR}: yes"
VERBOSE=
printf
EXT=tar.gz
EXT=zip
URL=
URL=
info "Tarball URL: ${UNDERLINE}${BLUE}${URL}${NO_COLOR}"
confirm "Install Starship ${GREEN}${VERSION}${NO_COLOR} to ${BOLD}${GREEN}${BIN_DIR}${NO_COLOR}?"
check_bin_dir "${BIN_DIR}"
install "${EXT}"
completed "Starship ${VERSION} installed"
printf
info "Please follow the steps for your shell to complete the installation:"
print_install
