#!/usr/bin/env bash
set -euo pipefail

# Build all .skill packages from source
# Reads each skill's manifest.json, copies declared references into the skill folder,
# runs package_skill.py, then cleans up.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
SKILLS_DIR="$REPO_ROOT/skills"
REFERENCES_DIR="$REPO_ROOT/references"
DIST_DIR="$REPO_ROOT/dist"

# Ensure dist/ exists
mkdir -p "$DIST_DIR"

# Track failures
ANY_FAILED=0

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name="$(basename "$skill_dir")"
    manifest="$skill_dir/manifest.json"

    if [ ! -f "$manifest" ]; then
        echo "WARNING: No manifest.json in $skill_name — skipping"
        continue
    fi

    echo "=========================================="
    echo "Building: $skill_name"
    echo "=========================================="

    # Parse references from manifest.json
    references=$(python3 -c "
import json, sys
with open('$manifest') as f:
    data = json.load(f)
for ref in data.get('references', []):
    print(ref)
")

    # Create references directory inside skill
    refs_dest="$skill_dir/references"
    mkdir -p "$refs_dest"

    # Copy each declared reference
    SKILL_FAILED=0
    for ref in $references; do
        # Try shared references first
        if [ -f "$REFERENCES_DIR/$ref" ]; then
            cp "$REFERENCES_DIR/$ref" "$refs_dest/$ref"
            echo "  Copied: references/$ref"
        # Then try spec-writer subdirectory
        elif [ -f "$REFERENCES_DIR/spec-writer/$ref" ]; then
            cp "$REFERENCES_DIR/spec-writer/$ref" "$refs_dest/$ref"
            echo "  Copied: references/spec-writer/$ref"
        else
            echo "ERROR: Reference '$ref' not found for skill '$skill_name'"
            echo "  Checked: $REFERENCES_DIR/$ref"
            echo "  Checked: $REFERENCES_DIR/spec-writer/$ref"
            # Clean up and fail
            rm -rf "$refs_dest"
            SKILL_FAILED=1
            ANY_FAILED=1
            break
        fi
    done

    # Skip packaging if reference copy failed
    if [ $SKILL_FAILED -ne 0 ]; then
        echo "FAILED: $skill_name (missing references)"
        echo ""
        continue
    fi

    # Validate and package
    echo ""
    python3 "$SCRIPTS_DIR/package_skill.py" "$skill_dir" "$DIST_DIR"
    RESULT=$?

    # Clean up references from skill source directory
    rm -rf "$refs_dest"

    if [ $RESULT -ne 0 ]; then
        echo "FAILED: $skill_name (packaging error)"
        ANY_FAILED=1
    fi

    echo ""
done

echo "=========================================="
if [ $ANY_FAILED -ne 0 ]; then
    echo "BUILD FAILED — see errors above"
    exit 1
else
    echo "BUILD COMPLETE"
    echo ""
    ls -la "$DIST_DIR"/*.skill
    exit 0
fi
