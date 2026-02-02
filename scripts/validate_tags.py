#!/usr/bin/env python3
"""
Pipeline validation script to ensure MSIDExecutionFlowTag.m has no UNTAGGED or duplicate tags.
This script is designed to run in CI/CD pipelines and will exit with code 1 if validation fails.
"""

import re
import sys
from pathlib import Path


def extract_existing_tags(content):
    """Extract all existing tags from the file content."""
    # Match patterns like: return @"y96sa";
    pattern = r'return @"([a-z0-9]{5})";'
    tags = re.findall(pattern, content)
    return tags


def check_for_duplicates(tags):
    """Check if there are any duplicate tags and return them."""
    tag_counts = {}
    for tag in tags:
        tag_counts[tag] = tag_counts.get(tag, 0) + 1
    
    duplicates = {tag: count for tag, count in tag_counts.items() if count > 1}
    return duplicates


def validate_tags(file_path):
    """Validate that the file has no UNTAGGED strings or duplicate tags."""
    # Read the file
    with open(file_path, 'r') as f:
        content = f.read()
    
    validation_passed = True
    
    # Check for UNTAGGED strings
    untagged_count = content.count('"UNTAGGED"')
    if untagged_count > 0:
        print(f"❌ VALIDATION FAILED: Found {untagged_count} UNTAGGED entries")
        print("   All execution flow tags must be assigned unique identifiers.")
        print("   Run scripts/retag_untagged.py to generate unique tags.")
        validation_passed = False
    else:
        print(f"✓ No UNTAGGED entries found")
    
    # Extract and check tags
    existing_tags_list = extract_existing_tags(content)
    existing_tags_set = set(existing_tags_list)
    
    print(f"✓ Found {len(existing_tags_list)} total tags")
    print(f"✓ Found {len(existing_tags_set)} unique tags")
    
    # Check for duplicate tags
    duplicates = check_for_duplicates(existing_tags_list)
    if duplicates:
        print(f"\n❌ VALIDATION FAILED: Duplicate tags found!")
        for tag, count in duplicates.items():
            print(f"   - Tag '{tag}' appears {count} times")
        print("   Each execution flow tag must be unique.")
        validation_passed = False
    else:
        print("✓ No duplicate tags found")
    
    return validation_passed


def main():
    # Default path relative to script location
    default_path = Path(__file__).parent.parent / "IdentityCore/src/telemetry/execution_flow/MSIDExecutionFlowTag.m"
    
    # Allow custom path as argument
    file_path = sys.argv[1] if len(sys.argv) > 1 else default_path
    file_path = Path(file_path)
    
    if not file_path.exists():
        print(f"❌ ERROR: File not found: {file_path}")
        sys.exit(1)
    
    print(f"Validating execution flow tags in: {file_path}")
    print("-" * 70)
    
    validation_passed = validate_tags(file_path)
    
    print("-" * 70)
    if validation_passed:
        print("✓ VALIDATION PASSED: All tags are properly assigned and unique")
        sys.exit(0)
    else:
        print("❌ VALIDATION FAILED: Please fix the issues above before committing")
        sys.exit(1)


if __name__ == "__main__":
    main()
