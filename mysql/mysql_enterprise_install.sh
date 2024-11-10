#!/bin/bash

# ╔═════════════════════════════════════════════════════════════════════════╗
# ║                           MySQL Setup Script                            ║
# ║                    Developed by burak@nsolidus.com                      ║
# ║                            Date: 10.11.2024                             ║
# ║             Install or remove MySQL with elegance and ease              ║
# ╚═════════════════════════════════════════════════════════════════════════╝

export DEBIAN_FRONTEND=noninteractive

# Check if the system was updated within the last hour
if [ -f "/var/lib/apt/periodic/update-success-stamp" ]; then
    last_update=$(stat -c %Y /var/lib/apt/periodic/update-success-stamp)
    current_time=$(date +%s)
    if (( (current_time - last_update) > 3600 )); then
        echo "Updating the system..."
        apt update && apt dist-upgrade -y && apt autoremove -y
    else
        echo "System update was done within the last hour; skipping update."
    fi
else
    echo "Updating the system (no recent update record found)..."
    apt update && apt dist-upgrade -y && apt autoremove -y
fi

# Display the main menu
echo "What would you like to do?"
echo "1. Install MySQL Enterprise Edition"
echo "2. Remove MySQL Enterprise Edition and related components"
echo "3. Install MySQL Community Edition (from Ubuntu repo)"
read -p "Please enter 1, 2, or 3: " choice

# Non-interactive option for configuration files
echo mysql-common mysql-common/overwrite_conf boolean true | debconf-set-selections
apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" update

# Installation functions
install_enterprise() {
    echo "Enter a password for the MySQL root alias (only used in alias setup):"
    read -s root_password
    echo "Enter the directory where the Enterprise installation packages are located (press Y for current directory):"
    read install_dir
    [[ "$install_dir" == "Y" ]] && install_dir="$(pwd)"

    echo "Starting installation..."

    # Install required dependencies
    echo "Installing initial required dependencies..."
    apt install -y libaio-dev libnuma1 libmecab2

    # Package installation order
    packages=(
        "mysql-common_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "mysql-commercial-server-core_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "mysql-commercial-client-plugins_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "mysql-commercial-client-core_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "libmysqlclient24_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "libmysqlclient-dev_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "mysql-commercial-client_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "mysql-client_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "mysql-commercial-server_8.4.2+commercial-1ubuntu24.04_amd64.deb"
        "mysql-server_8.4.2+commercial-1ubuntu24.04_amd64.deb"
    )

    for package in "${packages[@]}"; do
        echo "Installing package: $package"
        dpkg -i "$install_dir/$package"
        if [[ $? -ne 0 ]]; then
            echo "Error occurred during $package installation. Attempting to resolve dependencies..."
            apt-get -f install -y
        fi
    done

    # Start MySQL service
    echo "Starting MySQL service..."
    systemctl start mysql || echo "Failed to start MySQL service."
    systemctl enable mysql || echo "Failed to enable MySQL service on boot."

    # Add root alias to .bashrc
    echo "alias mysql='mysql -uroot -p$root_password'" >> ~/.bashrc
    echo "MySQL root alias added to .bashrc"

    # Summary
    echo -e "Installation complete! You can access MySQL using: mysql -uroot -p$root_password"
}

remove_enterprise() {
    echo -e "\nAre you sure you want to remove MySQL Enterprise Edition and related components? (Y/N)"
    read -p "Your choice: " confirmation
    [[ "$confirmation" != "Y" && "$confirmation" != "y" ]] && { echo "Aborted."; exit 1; }

    # Ask if the user wants a full removal
    echo -e "\nDo you want a full removal of MySQL and all its files? (Y/N)"
    read -p "Your choice: " full_removal
    if [[ "$full_removal" == "Y" || "$full_removal" == "y" ]]; then
        echo "Performing full MySQL removal..."
        apt remove mysql* -y
        apt purge mysql* -y
        rm -rf /var/lib/mysql
        rm -rf /etc/mysql/
        rm -rf /usr/lib/mysql/
        rm -rf /usr/bin/mysql
        echo "Full MySQL removal complete."
    else
        echo "Stopping MySQL service if active..."
        systemctl stop mysql 2>/dev/null || echo "MySQL service was not running."

        # Removing packages
        echo "Removing MySQL packages..."
        packages_to_remove=(
            "mysql-common"
            "libmysqlclient24"
            "mysql-commercial-client-plugins"
            "mysql-commercial-client-core"
            "libmysqlclient-dev"
            "mysql-commercial-client"
            "mysql-client"
            "mysql-commercial-server-core"
            "mysql-commercial-server"
            "mysql-server"
        )
        
        for pkg in "${packages_to_remove[@]}"; do
            dpkg -r "$pkg" || echo "$pkg could not be removed."
        done

        # Update bashrc to comment out MySQL alias if exists
        sed -i '/alias mysql=/s/^/#/' ~/.bashrc
        echo "MySQL alias in .bashrc has been commented out."

        # Retain /var/lib/mysql directory and remove only specific contents
        echo "Cleaning up additional MySQL-related directories in /var/lib..."
        rm -rf /var/lib/mysql-keyring /var/lib/mysql-files

        # Summary
        echo -e "Removal complete!\nNote: The directory /var/lib/mysql was not removed."
    fi
}

install_community() {
    echo "Starting MySQL Community Edition installation..."
    apt update && apt install -y mysql-server mysql-client

    # Start MySQL service
    echo "Starting MySQL service..."
    systemctl start mysql || echo "Failed to start MySQL service."
    systemctl enable mysql || echo "Failed to enable MySQL service on boot."

    # Summary
    echo -e "MySQL Community Edition installation complete!\nUse 'mysql -u root -p' to access."
}

# Main program flow
case $choice in
    1) install_enterprise ;;
    2) remove_enterprise ;;
    3) install_community ;;
    *) echo "Invalid choice. Exiting." ;;
esac
