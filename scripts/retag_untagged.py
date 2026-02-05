#!/usr/bin/env python3
"""
Script to replace all "UNTAGGED" strings in MSIDExecutionFlowConstants.m with unique 5-character tags.
Tags use lowercase letters a-z and digits 0-9.
"""

import re
import random
import sys
from pathlib import Path


def generate_tag(existing_tags):
    """Generate a unique 5-character tag using a-z and 0-9."""
    chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
    max_attempts = 10000
    
    for _ in range(max_attempts):
        tag = ''.join(random.choice(chars) for _ in range(5))
        if tag not in existing_tags:
            return tag
    
    raise RuntimeError("Failed to generate unique tag after many attempts")


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


def replace_untagged(file_path):
    """Replace all UNTAGGED strings with unique tags."""
    # Read the file
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Extract existing tags (as list to detect duplicates)
    existing_tags_list = extract_existing_tags(content)
    existing_tags_set = set(existing_tags_list)
    
    print(f"Found {len(existing_tags_list)} total tags")
    print(f"Found {len(existing_tags_set)} unique tags: {sorted(existing_tags_set)}")
    
    # Check for duplicate tags
    duplicates = check_for_duplicates(existing_tags_list)
    if duplicates:
        print("\n❌ ERROR: Duplicate tags found!")
        for tag, count in duplicates.items():
            print(f"  - '{tag}' appears {count} times")
        print("\nPlease fix duplicate tags before running this script.")
        sys.exit(1)
    
    print("✓ No duplicate tags found")
    
    # Find all UNTAGGED occurrences
    untagged_count = content.count('"UNTAGGED"')
    print(f"Found {untagged_count} UNTAGGED entries to replace")
    
    if untagged_count == 0:
        print("No UNTAGGED entries found. Nothing to do.")
        return
    
    # Generate new unique tags
    new_tags = []
    for i in range(untagged_count):
        tag = generate_tag(existing_tags_set | set(new_tags))
        new_tags.append(tag)
        print(f"Generated tag {i+1}/{untagged_count}: {tag}")
    
    # Replace UNTAGGED one by one to ensure each gets a unique tag
    modified_content = content
    for tag in new_tags:
        modified_content = modified_content.replace('"UNTAGGED"', f'"{tag}"', 1)
    
    # Verify all replacements were made
    remaining_untagged = modified_content.count('"UNTAGGED"')
    if remaining_untagged > 0:
        print(f"Warning: {remaining_untagged} UNTAGGED entries remain!")
        return
    
    # Write back to file
    with open(file_path, 'w') as f:
        f.write(modified_content)
    
    print(f"\n✓ Successfully replaced {untagged_count} UNTAGGED entries")
    print(f"New tags: {new_tags}")


def main():
    # Default path
    default_path = Path(__file__).parent.parent / "IdentityCore/src/telemetry/execution_flow/MSIDExecutionFlowConstants.m"
    
    # Allow custom path as argument
    file_path = sys.argv[1] if len(sys.argv) > 1 else default_path
    file_path = Path(file_path)
    
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)
    
    print(f"Processing file: {file_path}")
    print("-" * 60)
    
    replace_untagged(file_path)


if __name__ == "__main__":
    main()
