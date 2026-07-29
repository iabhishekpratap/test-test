#!/bin/bash
set -e


SERVICES=(
    "dir1"
    "dir2"
)


# Fetch latest tags

echo "Fetching repository..."

git fetch --all --tags --prune
git fetch --unshallow 2>/dev/null || true


# Detect changed files

echo "Detecting changed files..."

if git rev-parse HEAD~1 >/dev/null 2>&1; then
    CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD)
else
    CHANGED_FILES=$(git show --name-only --pretty="" HEAD)
fi

echo "$CHANGED_FILES"


# Detect changed services

CHANGED_SERVICES=()

for SERVICE in "${SERVICES[@]}"
do
    if echo "$CHANGED_FILES" | grep -q "^${SERVICE}/"; then
        CHANGED_SERVICES+=("$SERVICE")
    fi
done


# Exit if nothing changed


if [ ${#CHANGED_SERVICES[@]} -eq 0 ]; then
    echo
    echo "No microservice changed."
    exit 0
fi

echo
echo "Changed Services:"
printf '%s\n' "${CHANGED_SERVICES[@]}"


# Read latest commit message

COMMIT_MESSAGE=$(git log -1 --pretty=%B)

echo
echo "Commit Message:"
echo "$COMMIT_MESSAGE"

# Detect bump type


BUMP=""

if echo "$COMMIT_MESSAGE" | grep -Eiwq "major"; then
    BUMP="major"

elif echo "$COMMIT_MESSAGE" | grep -Eiwq "minor"; then
    BUMP="minor"

elif echo "$COMMIT_MESSAGE" | grep -Eiwq "patch"; then
    BUMP="patch"

else
    echo
    echo "Commit message doesn't contain major/minor/patch."
    echo "Skipping version bump."
    exit 0
fi

echo
echo "Version bump: $BUMP"

# Function to increment version


increment_version() {

    local VERSION=$1
    local TYPE=$2

    IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"

    case "$TYPE" in

        major)
            ((MAJOR++))
            MINOR=0
            PATCH=0
            ;;

        minor)
            ((MINOR++))
            PATCH=0
            ;;

        patch)
            ((PATCH++))
            ;;

    esac

    echo "${MAJOR}.${MINOR}.${PATCH}"
}


# Process every changed service

for SERVICE in "${CHANGED_SERVICES[@]}"
do

    echo
    echo "==================================="
    echo "Processing: $SERVICE"


    # Get latest tag

    LATEST_TAG=$(git tag \
        --list "${SERVICE}-v*" \
        --sort=-v:refname \
        | head -n 1)

    ####################################
    # No previous tag
    ####################################

    if [ -z "$LATEST_TAG" ]; then
        CURRENT_VERSION="0.0.0"
        echo "No existing tag found."
    else
        CURRENT_VERSION=${LATEST_TAG#${SERVICE}-v}
    fi

    echo "Current Version : $CURRENT_VERSION"

    ####################################
    # Calculate new version
    ####################################

    NEW_VERSION=$(increment_version "$CURRENT_VERSION" "$BUMP")

    echo "New Version     : $NEW_VERSION"

    ####################################
    # Create tag
    ####################################

    NEW_TAG="${SERVICE}-v${NEW_VERSION}"

    echo "Creating tag: $NEW_TAG"

    git tag "$NEW_TAG"

    ####################################
    # Push tag
    ####################################

    echo "Pushing tag..."

    git push origin "$NEW_TAG"

done

echo
echo "==================================="
echo "Version bump completed successfully."
echo "==================================="
