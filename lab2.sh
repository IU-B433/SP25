#!/bin/bash

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NO_COLOR="\033[0m"

script_path="$0"
echo -e "${YELLOW}[*] SHA-256 hash of $script_path:${NO_COLOR}"
sha256sum "$script_path" | awk '{ print $1 }' | while read -r line; do echo -e "${YELLOW}$line${NO_COLOR}"; done
echo "--------------------------"

SCORE=0

exit_with_error() {
    echo -e "${RED}[-] $1${NO_COLOR}"
    echo -e "${YELLOW}[+] Your score: $SCORE${NO_COLOR}"
    exit 1
}

check_users() {
    local errors=0
    for user in alice bob mallory chuck; do
        if ! id "$user" &>/dev/null; then
            echo -e "${RED}[-] User $user does not exist.${NO_COLOR}"
            errors=1
        fi
    done

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All specified users exist.${NO_COLOR}"
        SCORE=$((SCORE+10))
    else
        exit_with_error "User check failed."
    fi
}

check_directories() {
    local errors=0
    directories=(
        "/opt/data/financing"
        "/opt/data/development/bob"
        "/opt/data/development/mallory"
        "/opt/data/development/public"
        "/opt/data/marketing/public"
        "/opt/data/shared"
    )

    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            echo -e "${RED}[-] Directory $dir does not exist.${NO_COLOR}"
            errors=1
        fi
    done

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All specified directories exist.${NO_COLOR}"
        SCORE=$((SCORE+5))
    else
        exit_with_error "Directory check failed."
    fi
}

check_files() {
    local errors=0
    files=(
        "/opt/data/financing/costprojections.txt"
        "/opt/data/development/bob/bobscode.txt"
        "/opt/data/development/mallory/malloryscode.txt"
        "/opt/data/development/public/publiccode.txt"
        "/opt/data/marketing/strategy.txt"
        "/opt/data/marketing/public/slogan.txt"
        "/opt/data/shared/important.txt"
    )

    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            echo -e "${RED}[-] File $file does not exist.${NO_COLOR}"
            errors=1
        fi
    done

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All specified files exist.${NO_COLOR}"
        SCORE=$((SCORE+5))
    else
        exit_with_error "File check failed."
    fi
}

check_ownership() {
    local errors=0
    declare -A ownerships=(
        ["/opt/data/financing"]="alice"
        ["/opt/data/financing/costprojections.txt"]="alice"
        ["/opt/data"]="alice"
        ["/opt/data/shared"]="alice"
        ["/opt/data/development"]="bob"
        ["/opt/data/development/bob"]="bob"
        ["/opt/data/development/bob/bobscode.txt"]="bob"
        ["/opt/data/development/mallory"]="mallory"
        ["/opt/data/development/mallory/malloryscode.txt"]="mallory"
        ["/opt/data/development/public"]="bob|www-data"
        ["/opt/data/development/public/publiccode.txt"]="bob"
        ["/opt/data/marketing"]="chuck"
        ["/opt/data/marketing/strategy.txt"]="chuck"
        ["/opt/data/marketing/public"]="chuck|www-data"
        ["/opt/data/marketing/public/slogan.txt"]="chuck"
    )

    for path in "${!ownerships[@]}"; do
        IFS='|' read -r expected_owner expected_group <<< "${ownerships[$path]}"
        actual_owner=$(stat -c '%U' "$path" 2>/dev/null)
        actual_group=$(stat -c '%G' "$path" 2>/dev/null)
        
        if [ "$actual_owner" != "$expected_owner" ]; then
            echo -e "${RED}[-] Ownership of $path is $actual_owner but should be $expected_owner.${NO_COLOR}"
            errors=1
        fi
        
        if [ -n "$expected_group" ] && [ "$actual_group" != "$expected_group" ]; then
            echo -e "${RED}[-] Group of $path is $actual_group but should be $expected_group.${NO_COLOR}"
            errors=1
        fi
    done
    
    if find /opt/data/development/public -exec stat -c '%G' {} + 2>/dev/null | grep -qv "^www-data$"; then
        echo -e "${RED}[-] Not all files in /opt/data/development/public have 'www-data' as their group.${NO_COLOR}"
        errors=1
    fi

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All ownerships and groups are correctly set.${NO_COLOR}"
        SCORE=$((SCORE+20))
    else
        exit_with_error "Ownership check failed."
    fi
}


check_permissions() {
    local errors=0
    declare -A dir_permissions=(
        ["/opt/data"]="755"
        ["/opt/data/financing"]="700"
        ["/opt/data/financing/costprojections.txt"]="600"
        ["/opt/data/development"]="755"
        ["/opt/data/development/bob"]="700"
        ["/opt/data/development/bob/bobscode.txt"]="700"
        ["/opt/data/development/mallory"]="700"
        ["/opt/data/development/mallory/malloryscode.txt"]="700"
        ["/opt/data/marketing"]="700"
        ["/opt/data/marketing/strategy.txt"]="600"
        ["/opt/data/marketing/public"]="750"
        ["/opt/data/marketing/public/slogan.txt"]="640"
        ["/opt/data/shared/important.txt"]="777"
    )

    for dir in "${!dir_permissions[@]}"; do
        local expected_perm="${dir_permissions[$dir]}"
        local actual_perm=$(stat -c "%a" "$dir" 2>/dev/null)
        if [[ "$actual_perm" != "$expected_perm" ]]; then
            echo -e "${RED}[-] Permission for $dir is $actual_perm but should be $expected_perm.${NO_COLOR}"
            errors=1
        fi
    done

    local actual_perm=$(stat -c "%a" "/opt/data/shared" 2>/dev/null)
    if [[ "$actual_perm" != "1777" && "$actual_perm" != "777" ]]; then
        echo -e "${RED}[-] Permission for /opt/data/shared is $actual_perm but should be 1777.${NO_COLOR}"
        errors=1
    fi

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All permissions are correctly set.${NO_COLOR}"
        SCORE=$((SCORE+15))
    else
        exit_with_error "Permission check failed."
    fi
}

check_sticky_bit() {
    local errors=0
    local sticky_bit=$(stat -c "%a" "/opt/data/shared" 2>/dev/null)
    if [[ "$sticky_bit" != "1777" ]]; then
        errors=1
    fi

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] Sticky bit is set correctly.${NO_COLOR}"
        SCORE=$((SCORE+10))
    else
        exit_with_error "Sticky bit check failed."
    fi
}

check_suid_sgid() {
    if [ ! -f "/opt/whoami" ]; then
        exit_with_error "/opt/whoami does not exist."
    fi

    if [ ! -f "/opt/id" ]; then
        exit_with_error "/opt/id does not exist."
    fi

    local errors=0

    local whoami_owner=$(stat -c '%U' /opt/whoami 2>/dev/null)
    local whoami_perms=$(stat -c '%A' /opt/whoami 2>/dev/null)

    if [ "$whoami_owner" != "alice" ]; then
        echo -e "${RED}[-] Owner of /opt/whoami is $whoami_owner but should be alice.${NO_COLOR}"
        errors=1
    fi

    if [[ "$whoami_perms" != *s* ]]; then
        echo -e "${RED}[-] /opt/whoami does not have the setuid bit set as expected.${NO_COLOR}"
        errors=1
    fi

    local id_group=$(stat -c '%G' /opt/id 2>/dev/null)
    local id_perms=$(stat -c '%A' /opt/id 2>/dev/null)

    if [ "$id_group" != "www-data" ]; then
        echo -e "${RED}[-] Group of /opt/id is $id_group but should be www-data.${NO_COLOR}"
        errors=1
    fi

    if [[ "$id_perms" != *s* ]]; then
        echo -e "${RED}[-] /opt/id does not have the setgid bit set as expected.${NO_COLOR}"
        errors=1
    fi

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] SUID and SGID checks passed successfully.${NO_COLOR}"
        SCORE=$((SCORE+5))
    else
        exit_with_error "SUID or SGID check failed."
    fi
}

check_users
check_directories
check_files
check_ownership
check_permissions
check_sticky_bit
check_suid_sgid

echo -e "${GREEN}[+] All checks passed successfully.${NO_COLOR}"
echo -e "${GREEN}[+] Congratulations! ${NO_COLOR}"
echo -e "${YELLOW}[+] Your score is: $SCORE/70${NO_COLOR}"

