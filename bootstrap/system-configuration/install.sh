#!/bin/bash

#################
#### SYMLINKS
#################
symlink_if_not_exists() {
    local symlink_source_path="$1"
    local symlink_destination_path="$2"

    # Check if a file or symlink already exists at the destination
    if [ ! -f "$symlink_destination_path" ] && [ ! -L "$symlink_destination_path" ]; then
        echo "Symlinking $symlink_source_path -> $symlink_destination_path"
        sudo ln -s "$symlink_source_path" "$symlink_destination_path"
    else
        echo "Symlink or file already exists at $symlink_destination_path, ignoring."
    fi
}

manage_systemd_services() {
    # Dynamically find the absolute path of the directory containing THIS install.sh script
    local script_dir="$(dirname "$(readlink -f "$0")")"
    local source_dir="$script_dir/systemd-services"
    local dest_dir="/etc/systemd/system"

    # Verify the source directory actually exists
    if [ ! -d "$source_dir" ]; then
        echo "Error: Source directory $source_dir does not exist."
        return 1
    fi

    # Create an array to track successfully linked or existing services
    local services_to_manage=()

    # Loop through all .service files in your folder
    for service_file in "$source_dir"/*.service; do
        # Ensure it's a real file (safely skips if no .service files match)
        [ -e "$service_file" ] || continue
        
        local filename=$(basename "$service_file")
        symlink_if_not_exists "$service_file" "$dest_dir/$filename"
        
        # Track this service filename for the enable/start steps
        services_to_manage+=("$filename")
    done

    # If no services were found, exit early
    if [ ${#services_to_manage[@]} -eq 0 ]; then
        echo "No .service files found to manage."
        return 0
    fi
    
    # Reload systemd so it registers the new symlinks
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload

    # Loop back through our tracked services to enable and start them
    for service in "${services_to_manage[@]}"; do
        echo "Enabling $service..."
        sudo systemctl enable "$service"
        
        echo "Starting $service..."
        sudo systemctl start "$service"
    done

    echo "All systemd tasks completed successfully!"
}

# Execute the service management function
manage_systemd_services

