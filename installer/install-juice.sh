#!/bin/sh
set -e
set -o noglob

# Usage:
#   curl ... | ENV_VAR=... sh -
#       or
#   ENV_VAR=... ./install-juice.sh
#
# Example:
#   Installing:
#     curl ... | INSTALL_JUICE_TOKEN=m2m_XX INSTALL_JUICE_POOL=lab sh -
#     curl ... | INSTALL_JUICE_TOKEN=m2m_XX INSTALL_JUICE_POOL=lab sh - --cache-size=16
#
# Environment variables:
#   - JUICE_*
#     Environment variables which begin with JUICE_ will be preserved for the
#     systemd service to use. 
#
#   - INSTALL_JUICE_TOKEN (required)
#     The m2m token created on the web at https://app.juicelabs.co
#
#   - INSTALL_JUICE_POOL
#     The pool name or id to run the agent in, will not install the service if not supplied
#
#   - INSTALL_JUICE_FORCE_RESTART
#     If set to true will always restart the Juice service
#
#   - INSTALL_JUICE_SYMLINK
#     If set to 'skip' will not create symlinks, 'force' will overwrite,
#     default will symlink if command does not exist in path.
#
#   - INSTALL_JUICE_SKIP_ENABLE
#     If set to true will not enable or start Juice service.
#
#   - INSTALL_JUICE_SKIP_START
#     If set to true will not start Juice service.
#
#   - INSTALL_JUICE_VERSION
#     Version of Juice to download. Will attempt to download from the
#     stable channel if not specified.
#
#   - INSTALL_JUICE_USER
#     Username to run the Juice service as, defaults to 'juice'
#
#   - INSTALL_JUICE_CONTROLLER
#     Set a custom Juice Controller
#
#   - INSTALL_JUICE_INSTALL_DIR
#     Directory to install the binariesand uninstall script to, or use
#     /usr/local and /opt as the default
#
#   - INSTALL_JUICE_SYSTEMD_DIR
#     Directory to install systemd service and environment files to, or use
#     /etc/systemd/system as the default
#
#   - INSTALL_JUICE_EXEC or script arguments
#     Command with flags to use for launching Juice in the systemd service
#     The final systemd command resolves to a combination of EXEC and script args ($@).
#
#     The following commands result in the same behavior:
#       curl ... | INSTALL_JUICE_EXEC="--cache-size=16" sh -s -
#       curl ... | sh -s - --cache-size=16
#
#   - INSTALL_JUICE_NAME
#     Name of systemd service to create, will default to 'juice'
#


DOWNLOADER=

# --- helper functions for logs ---
info()
{
    echo '[INFO] ' "$@"
}
warn()
{
    echo '[WARN] ' "$@" >&2
}
error()
{
    echo '[ERROR] ' "$@" >&2
}
fatal()
{
    echo '[ERROR] ' "$@" >&2
    exit 1
}

# --- add quotes to command arguments ---
quote() {
    for arg in "$@"; do
        printf '%s\n' "$arg" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/"
    done
}

# --- add indentation and trailing slash to quoted args ---
quote_indent() {
    printf ' \\\n'
    for arg in "$@"; do
        printf '\t%s \\\n' "$(quote "$arg")"
    done
}

# --- escape most punctuation characters, except quotes, forward slash, and space ---
escape() {
    printf '%s' "$@" | sed -e 's/\([][!#$%&()*;<=>?\_`{|}]\)/\\\1/g;'
}

# --- escape double quotes ---
escape_dq() {
    printf '%s' "$@" | sed -e 's/"/\\"/g'
}

verify_system() {
    info "Checking system"
    verify_supervisor
    verify_libaries
    verify_downloader curl || verify_downloader wget || fatal 'Can not find curl or wget for downloading files'
}

# --- fatal if no systemd or openrc ---
verify_supervisor() {
    if [ -x /sbin/openrc-run ]; then
        HAS_OPENRC=true
        return
    fi
    if [ -x /bin/systemctl ] || type systemctl > /dev/null 2>&1; then
        HAS_SYSTEMD=true
        return
    fi
    fatal 'Can not find systemd or openrc to use as a process supervisor for juice'
}

# --- verify existence of network downloader executable ---
verify_downloader() {
    # Return failure if it doesn't exist or is no executable
    [ -x "$(command -v $1)" ] || return 1

    # Set verified executable as our downloader program and return success
    DOWNLOADER=$1
    return 0
}

# --- verify existence of required libraries ---
verify_libaries() {
    errors=0

    # Required glibc version
    required_major=2
    required_minor=27

    ldd_output=$(ldd --version 2>/dev/null | head -n1)
    version=$(echo "$ldd_output" | grep -o '[0-9][0-9]*\.[0-9][0-9]*' | head -n1)
    
    if [ -n "$version" ]; then
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        
        if [ -n "$major" ] && [ -n "$minor" ]; then
            if [ "$major" -lt "$required_major" ] || ( [ "$major" -eq "$required_major" ] && [ "$minor" -lt "$required_minor" ] ); then
                error "glibc version must be at least $required_major.$required_minor, found $major.$minor"
                errors=1
            fi
        else
            warn "Could not parse glibc version from: $ldd_output"
        fi
    else
        warn "Could not determine glibc version"
    fi

    installed_libs=$(ldconfig -p 2>/dev/null)

    client_deps="libnuma libatomic"
    agent_deps="libvulkan libgl libnvidia-encode"

    for dep in ${client_deps}; do
        info "$dep"
        if ! echo "$installed_libs" | grep -q $dep; then
            error "missing library $dep"
            errors=1
        fi
    done

    missing_for_agent=""
    for dep in ${agent_deps}; do
        info "$dep"
        if ! echo "$installed_libs" | grep -q $dep; then
            if [ -z "${INSTALL_JUICE_POOL}" ]; then
                missing_for_agent="$dep $missing_for_agent"
            else
                error "missing library $dep"
                errors=1
            fi
        fi
    done

    if [ "$errors" -gt 0 ]; then
        fatal 'Please correct the above errors'
    fi

    if [ -n "$missing_for_agent" ]; then
        warn "Client dependencies are met, but the following are missing if you want to run an agent: $missing_for_agent"
    fi
}

# --- verify juice token ---
verify_token() {
    set +e
    if [ -z "${INSTALL_JUICE_TOKEN}" ]; then
        fatal "INSTALL_JUICE_TOKEN is not set"
    fi
    info "Checking token"
    check_url="https://${INSTALL_CONTROLLER}/v1/status"
    case $DOWNLOADER in
        curl)
            curl -f -L -s -S -H "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${check_url} > /dev/null 2>&1
            ;;
        wget)
            wget -qO - --spider --header "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${check_url} > /dev/null 2>&1
            ;;
        *)
            fatal "Incorrect downloader executable '$DOWNLOADER'"
            ;;
    esac
    # Abort if download command failed
    [ $? -eq 0 ] || fatal 'Token check failed'
}

# --- define needed environment variables ---
setup_env() {
    info "Configuring environment"
    # --- use command args if passed or create default ---
    SYSTEM_NAME=juice
    CMD_JUICE=juice
    BIN_DIR=/usr/local/bin
    DATA_DIR=/var/lib/juice
    CMD_JUICE_EXEC="agent run --service --service-config \"${DATA_DIR}/agent_service.cfg\" --config-directory \"${DATA_DIR}\" --log-file stdout --stderr stdout --stdout \"${DATA_DIR}/logs/agent_service.log\" --log-level info $(quote_indent "$@")"


    # --- check for invalid characters in system name ---
    valid_chars=$(printf '%s' "${SYSTEM_NAME}" | sed -e 's/[][!#$%&()*;<=>?\_`{|}/[:space:]]/^/g;' )
    if [ "${SYSTEM_NAME}" != "${valid_chars}"  ]; then
        invalid_chars=$(printf '%s' "${valid_chars}" | sed -e 's/[^^]/ /g')
        fatal "Invalid characters for system name:
            ${SYSTEM_NAME}
            ${invalid_chars}"
    fi

    # --- use sudo if we are not already root ---
    SUDO=sudo
    if [ $(id -u) -eq 0 ]; then
        SUDO=
    fi

    # --- use systemd type simple ---
    SYSTEMD_TYPE=simple

    # --- use binary install directory if defined or create default ---
    if [ -n "${INSTALL_JUICE_INSTALL_DIR}" ]; then
        INSTALL_DIR=${INSTALL_JUICE_INSTALL_DIR}
    else
        # --- use /usr/local/bin if root can write to it, otherwise use /opt/bin if it exists
        INSTALL_ROOT=/usr/local
        if ! $SUDO sh -c "touch ${INSTALL_ROOT}/juice-ro-test && rm -rf ${INSTALL_ROOT}/juice-ro-test"; then
            if [ -d /opt ]; then
                INSTALL_ROOT=/opt
            fi
        fi
        INSTALL_DIR=${INSTALL_ROOT}/juice
    fi
    INSTALL_DIR=${INSTALL_ROOT}/juice

    # --- use systemd directory if defined or create default ---
    if [ -n "${INSTALL_JUICE_SYSTEMD_DIR}" ]; then
        SYSTEMD_DIR="${INSTALL_JUICE_SYSTEMD_DIR}"
    else
        SYSTEMD_DIR=/etc/systemd/system
    fi

    # --- set related files from system name ---
    SERVICE_JUICE=${SYSTEM_NAME}.service
    UNINSTALL_JUICE_SH=${UNINSTALL_JUICE_SH:-${INSTALL_DIR}/uninstall.sh}
    KILLALL_JUICE_SH=${KILLALL_JUICE_SH:-${INSTALL_DIR}/juice-killall.sh}

    # --- use service or environment location depending on systemd/openrc ---
    if [ "${HAS_SYSTEMD}" = true ]; then
        FILE_JUICE_SERVICE=${SYSTEMD_DIR}/${SERVICE_JUICE}
        FILE_JUICE_ENV=${SYSTEMD_DIR}/${SERVICE_JUICE}.env
    elif [ "${HAS_OPENRC}" = true ]; then
        $SUDO mkdir -p /etc/juice
        FILE_JUICE_SERVICE=/etc/init.d/${SYSTEM_NAME}
        FILE_JUICE_ENV=/etc/juice/${SYSTEM_NAME}.env
    fi

    # --- use user if defined or create default ---
    if [ -n "${INSTALL_JUICE_USER}" ]; then
        INSTALL_USER=${INSTALL_JUICE_USER}
    else
        INSTALL_USER=juice
    fi
    if ! id ${INSTALL_USER} >/dev/null 2>&1; then
        CREATE_USER=1
    else
        CREATE_USER=0
    fi

    # --- use default controller if not defined
    if [ -n "${INSTALL_JUICE_CONTROLLER}" ]; then
        INSTALL_CONTROLLER=${INSTALL_JUICE_CONTROLLER}
    else
        INSTALL_CONTROLLER="electra.juicelabs.co"
    fi

    # --- get hash of config & exec for currently installed juice ---
    PRE_INSTALL_HASHES=$(get_installed_hashes)
}

# --- verify an executable juice binary is installed ---
verify_juice_is_executable() {
    if [ ! -x ${INSTALL_DIR}juice ]; then
        fatal "Executable juice binary not found at ${INSTALL_DIR}/juice"
    fi
}

# --- set arch and suffix, fatal if architecture not supported ---
setup_verify_arch() {
    if [ -z "$ARCH" ]; then
        ARCH=$(uname -m)
    fi
    case $ARCH in
        amd64)
            ARCH=amd64
            SUFFIX=
            ;;
        x86_64)
            ARCH=amd64
            SUFFIX=
            ;;
        arm64)
            ARCH=arm64
            SUFFIX=-${ARCH}
            ;;
        *)
            fatal "Unsupported architecture $ARCH"
    esac
}

# --- create temporary directory and cleanup when done ---
setup_tmp() {
    TMP_DIR=$(mktemp -d -t juice-install.XXXXXXXXXX)
    TMP_HASH=${TMP_DIR}/juice.hash
    TMP_BIN=${TMP_DIR}/juice-linux.tar.gz
    cleanup() {
        code=$?
        set +e
        trap - EXIT
        info "Cleaning up temporary files"
        rm -rf ${TMP_DIR}
        exit $code
    }
    trap cleanup INT EXIT
}

# --- use desired juice version if defined or find version from channel ---
get_release_version() {
    if [ "${INSTALL_JUICE_VERSION}" != "" ]; then

        case "${INSTALL_JUICE_VERSION}" in
        *"+"*)
            VERSION_JUICE=${INSTALL_JUICE_VERSION}
            ;;

            *)
            version_url="https://${INSTALL_CONTROLLER}/v1/user/releases"
            case $DOWNLOADER in
                curl)
                    VERSION_SUFFIX=$(curl -w -L -s -S -H "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${version_url} | sed -n "s/.*\"version\":\"${INSTALL_JUICE_VERSION}\([^\"]*\)\".*/\1/p")
                    ;;
                wget)
                    VERSION_SUFFIX=$(wget -qO - --header "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${version_url} | sed -n 's/.*"version":"${INSTALL_JUICE_VERSION}\([^"]*\)".*/\1/p')
                    ;;
                *)
                    fatal "Incorrect downloader executable '$DOWNLOADER'"
                    ;;
            esac
            if [ -n "${VERSION_SUFFIX}" ]; then
                VERSION_JUICE="${INSTALL_JUICE_VERSION}${VERSION_SUFFIX}"
            else
                fatal "No matching version found for ${INSTALL_JUICE_VERSION}"
            fi
        ;;
        esac
    else
        info "Finding release"
        version_url="https://${INSTALL_CONTROLLER}/v1/build/latest"
        case $DOWNLOADER in
            curl)
                VERSION_JUICE=$(curl -w -L -s -S -H "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${version_url} | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
                ;;
            wget)
                VERSION_JUICE=$(wget -qO - --header "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${version_url} | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
                ;;
            *)
                fatal "Incorrect downloader executable '$DOWNLOADER'"
                ;;
        esac
    fi
    info "Using ${VERSION_JUICE} as release"
}

get_release_hash_and_url() {
    info "Getting release hash and url"
    build_url="https://${INSTALL_CONTROLLER}/v1/build/${VERSION_JUICE}"
    case $DOWNLOADER in
        curl)
            HASH_EXPECTED=$(curl -w -L -s -S -H "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${build_url} | sed -n 's/.*"linuxFilenameSha256sum":"\([^[:space:]]*\).*/\1/p')
            ;;
        wget)
            HASH_EXPECTED=$(wget -qO - --header "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${build_url} | sed -n 's/.*"linuxFilenameSha256sum":"\([^[:space:]]*\).*/\1/p')
            ;;
        *)
            fatal "Incorrect downloader executable '$DOWNLOADER'"
            ;;
    esac   

    release_url="https://${INSTALL_CONTROLLER}/v2/download/linux/${VERSION_JUICE}"
    case $DOWNLOADER in
        curl)
            BIN_URL=$(curl -w -L -s -S -H "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${release_url} | sed -n 's/.*"url":"\([^"]*\)".*/\1/p' | sed 's/\\u0026/\&/g' )
            ;;
        wget)
            BIN_URL=$(wget -qO - --header "Authorization: Bearer ${INSTALL_JUICE_TOKEN}" ${release_url} | sed -n 's/.*"url":"\([^"]*\)".*/\1/p' | sed 's/\\u0026/\&/g')
            ;;
        *)
            fatal "Incorrect downloader executable '$DOWNLOADER'"
            ;;
    esac
}

# --- download from github url ---
download() {
    [ $# -eq 2 ] || fatal 'download needs exactly 2 arguments'

    # Disable exit-on-error so we can do custom error messages on failure
    set +e

    # Default to a failure status
    status=1

    case $DOWNLOADER in
        curl)
            curl -so "$1" -fL "$2"
            status=$?
            ;;
        wget)
            wget -qO "$1" "$2"
            status=$?
            ;;
        *)
	    # Enable exit-on-error for fatal to execute
	    set -e
            fatal "Incorrect executable '$DOWNLOADER'"
            ;;
    esac

    # Re-enable exit-on-error
    set -e

    # Abort if download command failed
    [ $status -eq 0 ] || fatal 'Download failed'
}

# --- download binary from github url ---
download_binary() {
    SIMPLE_URL=$(echo "${BIN_URL}" | sed 's/?.*$//')
    info "Downloading binary ${SIMPLE_URL} to ${TMP_BIN}"
    download ${TMP_BIN} ${BIN_URL}
}

# --- verify downloaded binary hash ---
verify_binary() {
    info "Verifying binary download"
    HASH_BIN=$(sha256sum ${TMP_BIN})
    HASH_BIN=${HASH_BIN%%[[:blank:]]*}
    if [ "${HASH_EXPECTED}" != "${HASH_BIN}" ]; then
        fatal "Download sha256 does not match ${HASH_EXPECTED}, got ${HASH_BIN}"
    fi
}

# --- setup permissions and move binary to system directory ---
setup_binary() {
    chmod 755 ${TMP_BIN}
    info "Installing juice to ${INSTALL_DIR}/juice"
    $SUDO chown root:root ${TMP_BIN}
    $SUDO mv -f ${TMP_BIN} ${INSTALL_DIR}/juice
}

# --- download and verify juice ---
download_and_verify() {

    setup_verify_arch
    setup_tmp
    get_release_version
    get_release_hash_and_url

    download_binary
    verify_binary
}


# --- add additional utility links ---
create_symlinks() {
    [ "${INSTALL_JUICE_SYMLINK}" = skip ] && return

    for cmd in juice; do
        if [ ! -e ${BIN_DIR}/${cmd} ] || [ "${INSTALL_JUICE_SYMLINK}" = force ]; then
            info "Creating ${BIN_DIR}/${cmd} symlink"
            $SUDO ln -sf ${INSTALL_DIR}/${cmd} ${BIN_DIR}/${cmd}
        else
            info "Skipping ${BIN_DIR}/${cmd} symlink, already exists"
        fi
    done
}

# --- create uninstall script ---
create_uninstall() {
    $SUDO mkdir -p ${INSTALL_DIR}
    $SUDO mkdir -p ${DATA_DIR}
    $SUDO touch ${DATA_DIR}/uninstall.state
    if ! grep -q "CREATE_USER=" ${DATA_DIR}/uninstall.state 2>/dev/null; then
        $SUDO tee -a ${DATA_DIR}/uninstall.state >/dev/null <<EOS
CREATE_USER=${CREATE_USER}
EOS
    fi
    info "Creating uninstall script ${UNINSTALL_JUICE_SH}"
    $SUDO tee ${UNINSTALL_JUICE_SH} >/dev/null <<EOF
#!/bin/sh
set -x

. ${DATA_DIR}/uninstall.state

if command -v systemctl; then
    systemctl stop ${SYSTEM_NAME}
    systemctl disable ${SYSTEM_NAME}
    systemctl reset-failed ${SYSTEM_NAME}
    systemctl daemon-reload
fi
if command -v rc-update; then
    rc-update delete ${SYSTEM_NAME} default
fi

rm -f ${FILE_JUICE_SERVICE}
rm -f ${FILE_JUICE_ENV}
rm -rf ${BIN_DIR}/juice
rm -rf ${DATA_DIR}
rm -f /tmp/juice-agent.lock

# Remove user if necessary
if [ \${CREATE_USER} -eq 1 ]; then
    # Try userdel first (most common)
    if command -v userdel >/dev/null 2>&1; then
        $SUDO userdel --remove ${INSTALL_USER} || true
        $SUDO groupdel ${INSTALL_USER} 2>/dev/null || true
    # Fallback to deluser (Debian/Ubuntu style)
    elif command -v deluser >/dev/null 2>&1; then
        $SUDO deluser --remove-home ${INSTALL_USER} || true
        $SUDO delgroup ${INSTALL_USER} 2>/dev/null || true
    else
        warn "Neither userdel nor deluser found, skipping user removal"
    fi
fi

rm -rf ${INSTALL_DIR}

set +x
echo "Uninstall complete"

EOF
    $SUDO chmod 755 ${UNINSTALL_JUICE_SH}
    $SUDO chown root:root ${UNINSTALL_JUICE_SH}
}

create_users_and_directories() {
    # Create juice user if it doesn't exist
    if [ ${CREATE_USER} -eq 1 ]; then
        info "Creating ${INSTALL_USER} user"
        
        # Try useradd first (most common)
        if command -v useradd >/dev/null 2>&1; then
            $SUDO useradd --system --user-group --home-dir ${DATA_DIR} --no-create-home --shell /bin/false ${INSTALL_USER}
        # Fallback to adduser (Debian/Ubuntu style)
        elif command -v adduser >/dev/null 2>&1; then
            $SUDO adduser --system --group --home ${DATA_DIR} --no-create-home --shell /bin/false ${INSTALL_USER}
        else
            fatal "Neither useradd nor adduser found"
        fi
    else
        info "User ${INSTALL_USER} already exists"
    fi

    $SUDO mkdir -p ${DATA_DIR}
    uid=$(id -u ${INSTALL_USER})
    $SUDO ${INSTALL_DIR}/juice \
        --no-banner \
        --controller ${INSTALL_CONTROLLER} \
        --token ${INSTALL_JUICE_TOKEN} \
        agent service install \
        --config-directory ${DATA_DIR} \
        --desktop-user ${uid} \
        ${INSTALL_JUICE_POOL} > /dev/null 2>&1 || fatal "Could not install service"
    
    $SUDO chown -R ${INSTALL_USER}:${INSTALL_USER} ${DATA_DIR}
}

install_binaries() {
    $SUDO tar -xzf ${TMP_BIN} -C ${INSTALL_DIR}
    # Abort if extact command failed
    [ $? -eq 0 ] || fatal 'Binary installation failed'

    cwd=$(pwd)
    cd ${INSTALL_DIR}
    $SUDO sed -i '/  uninstall\.sh$/d' sha256sums
    sha256sum uninstall.sh | $SUDO tee -a sha256sums > /dev/null
    cd ${cwd}
}

# --- disable current service if loaded --
systemd_disable() {
    $SUDO systemctl disable ${SYSTEM_NAME} >/dev/null 2>&1 || true
    $SUDO rm -f /etc/systemd/system/${SERVICE_JUICE} || true
    $SUDO rm -f /etc/systemd/system/${SERVICE_JUICE}.env || true
}

# --- write systemd service file ---
create_systemd_service_file() {
    info "systemd: Creating service file ${FILE_JUICE_SERVICE}"
    $SUDO tee ${FILE_JUICE_SERVICE} >/dev/null << EOF
[Unit]
Description=Juice GPU
Documentation=https://docs.juicelabs.co
Wants=network-online.target
After=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=${SYSTEMD_TYPE}
EnvironmentFile=-/etc/default/%N
EnvironmentFile=-/etc/sysconfig/%N
EnvironmentFile=-${FILE_JUICE_ENV}
Delegate=yes
User=${INSTALL_USER}
Restart=always
RestartSec=5s
ExecStart=${INSTALL_DIR}/${CMD_JUICE} ${CMD_JUICE_EXEC}
EOF
}

# --- write openrc service file ---
create_openrc_service_file() {
    LOG_FILE=/var/log/${SYSTEM_NAME}.log

    info "openrc: Creating service file ${FILE_JUICE_SERVICE}"
    $SUDO tee ${FILE_JUICE_SERVICE} >/dev/null << EOF
#!/sbin/openrc-run

depend() {
    after network-online
}

supervisor=supervise-daemon
name=${SYSTEM_NAME}
command="${INSTALL_DIR}/${CMD_JUICE}"
command_args="$(escape_dq "${CMD_JUICE_EXEC}")"

output_log=${LOG_FILE}
error_log=${LOG_FILE}

pidfile="/var/run/${SYSTEM_NAME}.pid"
respawn_delay=5
respawn_max=0

set -o allexport
if [ -f /etc/environment ]; then . /etc/environment; fi
if [ -f ${FILE_JUICE_ENV} ]; then . ${FILE_JUICE_ENV}; fi
set +o allexport
EOF
    $SUDO chmod 0755 ${FILE_JUICE_SERVICE}

    $SUDO tee /etc/logrotate.d/${SYSTEM_NAME} >/dev/null << EOF
${LOG_FILE} {
	missingok
	notifempty
	copytruncate
}
EOF
}

# --- write systemd or openrc service file ---
create_service_file() {
    [ "${HAS_SYSTEMD}" = true ] && create_systemd_service_file && restore_systemd_service_file_context
    [ "${HAS_OPENRC}" = true ] && create_openrc_service_file
    return 0
}

restore_systemd_service_file_context() {
    $SUDO restorecon -R -i ${FILE_JUICE_SERVICE} 2>/dev/null || true
    $SUDO restorecon -R -i ${FILE_JUICE_ENV} 2>/dev/null || true
}

# --- get hashes of the current juice bin and service files
get_installed_hashes() {
    $SUDO sha256sum ${INSTALL_DIR}/juice ${FILE_JUICE_SERVICE} ${FILE_JUICE_ENV} 2>&1 || true
}

# --- enable and start systemd service ---
systemd_enable() {
    info "systemd: Enabling ${SYSTEM_NAME} unit"
    $SUDO systemctl enable ${FILE_JUICE_SERVICE} >/dev/null
    $SUDO systemctl daemon-reload >/dev/null
}

systemd_start() {
    info "systemd: Starting ${SYSTEM_NAME}"
    $SUDO systemctl restart ${SYSTEM_NAME}
}

# --- enable and start openrc service ---
openrc_enable() {
    info "openrc: Enabling ${SYSTEM_NAME} service for default runlevel"
    $SUDO rc-update add ${SYSTEM_NAME} default >/dev/null
}

openrc_start() {
    info "openrc: Starting ${SYSTEM_NAME}"
    $SUDO ${FILE_JUICE_SERVICE} restart
}

# --- startup systemd or openrc service ---
service_enable_and_start() {
    [ "${INSTALL_JUICE_SKIP_ENABLE}" = true ] && return

    [ "${HAS_SYSTEMD}" = true ] && systemd_enable
    [ "${HAS_OPENRC}" = true ] && openrc_enable

    [ "${INSTALL_JUICE_SKIP_START}" = true ] && return

    POST_INSTALL_HASHES=$(get_installed_hashes)
    if [ "${PRE_INSTALL_HASHES}" = "${POST_INSTALL_HASHES}" ] && [ "${INSTALL_JUICE_FORCE_RESTART}" != true ]; then
        info 'No change detected so skipping service start'
        return
    fi

    [ "${HAS_SYSTEMD}" = true ] && systemd_start
    [ "${HAS_OPENRC}" = true ] && openrc_start
    return 0
}

# --- re-evaluate args to include env command ---
eval set -- $(escape "${INSTALL_JUICE_EXEC}") $(quote "$@")

# --- run the install process --
{
    verify_system
    setup_env "$@"
    verify_token
    download_and_verify
    create_uninstall
    systemd_disable
    install_binaries
    create_symlinks

    if [ ! -z $INSTALL_JUICE_POOL ]; then
        create_users_and_directories
        create_service_file
        service_enable_and_start
    fi
}
