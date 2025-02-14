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

check_users_directories() {
    local errors=0
    base_dir="/opt/users"
    users=("alice" "bob" "mallory" "chuck")

    if [ ! -d "$base_dir" ]; then
        echo -e "${RED}[-] Directory $base_dir does not exist.${NO_COLOR}"
        errors=1
    else
        owner=$(stat -c '%U' "$base_dir" 2>/dev/null)
        perm=$(stat -c '%a' "$base_dir" 2>/dev/null)

        if [ "$owner" != "mallory" ]; then
            echo -e "${RED}[-] $base_dir should be owned by mallory.${NO_COLOR}"
            errors=1
        fi

        if [ "$perm" != "711" ]; then
            echo -e "${RED}[-] Permissions for $base_dir should be 711.${NO_COLOR}"
            errors=1
        fi
    fi

    for user in "${users[@]}"; do
        user_dir="$base_dir/$user"
        if [ ! -d "$user_dir" ]; then
            echo -e "${RED}[-] Directory $user_dir does not exist.${NO_COLOR}"
            errors=1
        else
            owner=$(stat -c '%U' "$user_dir" 2>/dev/null)
            perm=$(stat -c '%a' "$user_dir" 2>/dev/null)
            
            if [ "$owner" != "$user" ]; then
                echo -e "${RED}[-] $user_dir should be owned by $user.${NO_COLOR}"
                errors=1
            fi
            
            if [ "$perm" != "700" ]; then
                echo -e "${RED}[-] Permissions for $user_dir should be 700.${NO_COLOR}"
                errors=1
            fi
        fi
    done

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All user directories exist with correct ownership and permissions.${NO_COLOR}"
    else
        exit_with_error "User directory check failed."
    fi
}

check_home_and_shell() {
    local errors=0
    base_dir="/opt/users"
    users=("alice" "bob" "mallory" "chuck")

    for user in "${users[@]}"; do
        expected_home="$base_dir/$user"
        current_home=$(eval echo ~$user 2>/dev/null)
        current_shell=$(getent passwd "$user" | cut -d: -f7)

        if [ "$current_home" != "$expected_home" ]; then
            echo -e "${RED}[-] Home directory for $user should be $expected_home but is $current_home.${NO_COLOR}"
            errors=1
        fi

        if [ "$current_shell" != "/bin/bash" ]; then
            echo -e "${RED}[-] Shell for $user should be /bin/bash but is $current_shell.${NO_COLOR}"
            errors=1
        fi
    done

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All users have correct home directories and shell settings.${NO_COLOR}"
        SCORE=$((SCORE+10))
    else
        exit_with_error "Home directory or shell check failed."
    fi
}

check_groups_and_folders() {
    local errors=0
    declare -A group_memberships=(
        ["development"]="bob mallory"
        ["management"]="alice"
        ["marketing"]="chuck"
    )

    for group in "${!group_memberships[@]}"; do
        if ! getent group "$group" >/dev/null; then
            echo -e "${RED}[-] Group $group does not exist.${NO_COLOR}"
            errors=1
        else
            for user in ${group_memberships[$group]}; do
                if ! id -nG "$user" | grep -qw "$group"; then
                    echo -e "${RED}[-] User $user is not a member of $group.${NO_COLOR}"
                    errors=1
                fi
            done
        fi
    done

    declare -A folder_groups=(
        ["/opt/data/development"]="development"
        ["/opt/data/financing"]="management"
        ["/opt/data/marketing"]="marketing"
    )

    for folder in "${!folder_groups[@]}"; do
        if [ ! -d "$folder" ]; then
            echo -e "${YELLOW}[!] Directory $folder does not exist, creating it.${NO_COLOR}"
            mkdir -p "$folder"
        fi

        actual_group=$(stat -c '%G' "$folder" 2>/dev/null)
        if [ "$actual_group" != "${folder_groups[$folder]}" ]; then
            echo -e "${RED}[-] Group of $folder is $actual_group but should be ${folder_groups[$folder]}.${NO_COLOR}"
            errors=1
        fi
    done

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] All groups and folder permissions are correctly set.${NO_COLOR}"
        SCORE=$((SCORE+10))
    else
        exit_with_error "Group or folder check failed."
    fi
}

check_development_shared_folder() {
    local errors=0
    shared_dir="/opt/data/development/shared"

    if [ ! -d "$shared_dir" ]; then
		exit_with_error "Directory $shared_dir does not exist"
    else
        owner=$(stat -c '%U' "$shared_dir" 2>/dev/null)
        group=$(stat -c '%G' "$shared_dir" 2>/dev/null)
        perm=$(stat -c '%a' "$shared_dir" 2>/dev/null)

        if [ "$owner" != "alice" ]; then
		    exit_with_error "$shared_dir should be owned by alice."
        fi

        if [ "$group" != "development" ]; then
		    exit_with_error "$shared_dir should have group development."
        fi

		if [[ "$perm" != "2570" && "$perm" != "3570" && "$perm" != "570" ]]; then
		    exit_with_error "Permissions for $shared_dir is incorrect, please review the folder's permission."
        fi

		if [[ "$perm" != "2570" && "$perm" != "3570" ]]; then
		    exit_with_error "New files created in $shared_dir is not associated to group development"
		fi

		if [ $(stat -c "%A" "$shared_dir" | cut -c7) != "s" ]; then
		    exit_with_error "Sticky bit is not set on $shared_dir, users can delete others' files"
        fi
    fi

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] Shared development folder is correctly configured.${NO_COLOR}"
        SCORE=$((SCORE+10))
    else
        exit_with_error "Development shared directory permission check failed."
    fi
}

check_extended_acl_permissions() {
    local errors=0
    shared_dir="/opt/data/development/shared"
    code_file="$shared_dir/code.txt"

    if ! command -v getfacl &>/dev/null || ! command -v setfacl &>/dev/null; then
        exit_with_error "getfacl or setfacl command not found. ACL utilities must be installed."
    fi

    if [ ! -f "$code_file" ]; then
        exit_with_error "code.txt does not exist in $shared_dir."
    fi
	
    owner=$(stat -c '%U' "$code_file" 2>/dev/null)
    group=$(stat -c '%G' "$code_file" 2>/dev/null)

    if [ "$owner" != "bob" ]; then
        exit_with_error "code.txt should be created by bob."
    fi
    if [ "$group" != "development" ]; then
        exit_with_error "code.txt should be associated with the development group."
    fi

	SCORE=$((SCORE+5))

    if ! getent passwd abcd >/dev/null; then
        exit_with_error "User abcd does not exist."
    fi

    if id -nG abcd | grep -qw "development"; then
        exit_with_error "User abcd should not be in the development group."
	fi

    if ! getfacl -p "$code_file" | grep -q "user:abcd:r-x"; then
        exit_with_error "abcd does not have correct permission on /opt/data/development/shared/code.txt."
    fi

	SCORE=$((SCORE+15))

    if ! getfacl -p "$shared_dir" | grep -q "user:abcd:rwx"; then
        exit_with_error "abcd does not have correct permission on $shared_dir"
    fi

	if [ $errors -eq 0 ]; then
        echo -e "${GREEN}[+] Extended ACL permissions are correctly set.${NO_COLOR}"
        SCORE=$((SCORE+10))
    else
        exit_with_error "ACL permission check failed."
    fi
}

check_users_directories
check_home_and_shell
check_groups_and_folders
check_development_shared_folder
check_extended_acl_permissions

echo -e "${GREEN}[+] All checks passed successfully.${NO_COLOR}"
echo -e "${GREEN}[+] Congratulations! ${NO_COLOR}"
echo -e "${YELLOW}[+] Your score is: $SCORE/60${NO_COLOR}"

