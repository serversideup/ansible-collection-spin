#!/bin/bash

check_pending_changes() {
    if ! git diff-index --quiet HEAD --; then
        echo "❌ There are uncommitted changes in the repository."
        echo "👉 Please commit or stash them before running this script."
        exit 1
    fi
}

show_help() {
    echo "Version Bumper Script"
    echo "Usage: $0 <command>"
    echo ""
    echo "This script is used for bumping the version number in the galaxy.yml file following semantic versioning."
    echo ""
    echo "Commands:"
    echo "  major        Bumps the major version (e.g., 1.2.3 -> 2.0.0)"
    echo "  minor        Bumps the minor version (e.g., 1.2.3 -> 1.3.0)"
    echo "  patch        Bumps the patch version (e.g., 1.2.3 -> 1.2.4)"
    echo "  premajor     Creates a pre-release major version (e.g., 1.2.3 -> 2.0.0-0)"
    echo "  preminor     Creates a pre-release minor version (e.g., 1.2.3 -> 1.3.0-0)"
    echo "  prepatch     Creates a pre-release patch version (e.g., 1.2.3 -> 1.2.4-0)"
    echo "  prerelease   Bumps the pre-release version (e.g., 1.2.3-0 -> 1.2.3-1)"
    echo ""
    echo "Examples:"
    echo "  $0 patch      # Bumps the patch version"
    echo "  $0 minor      # Bumps the minor version"
    echo "  $0 major      # Bumps the major version"
    echo "  $0 prerelease # Bumps the prerelease version"
    echo ""
    echo "Note: Make sure that 'yq' is installed and functioning properly."
}

bump_version() {
    local version=$1
    local type=$2

    # Break the version number into its components
    local major=$(echo $version | cut -d. -f1)
    local minor=$(echo $version | cut -d. -f2)
    local patch=$(echo $version | cut -d. -f3)

    # Remove any pre-release or build metadata
    patch=${patch%%[-+]*}

    # Increment the appropriate part of the version number
    case $type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        premajor)
            major=$((major + 1))
            minor=0
            patch=0
            version="$major.$minor.$patch-0"
            ;;
        preminor)
            minor=$((minor + 1))
            patch=0
            version="$major.$minor.$patch-0"
            ;;
        prepatch)
            patch=$((patch + 1))
            version="$major.$minor.$patch-0"
            ;;
        prerelease)
            if [[ $version =~ "-" ]]; then
                local number=$(echo $version | cut -d- -f2)
                number=$((number + 1))
                version="$major.$minor.$patch-$number"
            else
                version="$major.$minor.$patch-0"
            fi
            ;;
        *)
            echo "Invalid version type: $type"
            exit 1
            ;;
    esac

    if [ "$type" != "prerelease" ] && [ "$type" != "premajor" ] && [ "$type" != "preminor" ] && [ "$type" != "prepatch" ]; then
        version="$major.$minor.$patch"
    fi

    echo $version
}

# Check if argument is provided
if [ $# -ne 1 ]; then
    show_help
    exit 1
fi

check_pending_changes

# Read the current version
current_version=$(yq e '.version' galaxy.yml)

# Bump the version
new_version=$(bump_version $current_version $1)

# Update galaxy.yml with the new version
yq e ".version = \"$new_version\"" -i galaxy.yml

# # Commit and tag
# git add galaxy.yml
# git commit -m "Bump version to $new_version"
# git tag $new_version

# # Push changes
# git push origin main
# git push origin --tags
