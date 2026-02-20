#!/usr/bin/env python3
"""
Script to replace all "UNTAGGED" strings in MSIDExecutionFlowConstants.m with unique 5-character tags.
Tags use lowercase letters a-z and digits 1-9.
"""

import argparse
import re
import random
import sys
from pathlib import Path


def generate_tag(existing_tags, length, charset):
    """Generate a unique tag using specified length and charset."""
    max_attempts = 10000
    
    for _ in range(max_attempts):
        tag = ''.join(random.choice(charset) for _ in range(length))
        if tag not in existing_tags:
            return tag
    
    raise RuntimeError("Failed to generate unique tag after many attempts")


def extract_existing_tags(content, length, charset):
    """Extract all existing tags from the file content."""
    # Match patterns like: return @"y96sa";
    # Escape special regex characters in charset
    escaped_charset = re.escape(charset)
    pattern = rf'return @"([{escaped_charset}]{{{length}}})";'
    tags = re.findall(pattern, content)
    return tags


def check_for_duplicates(tags):
    """Check if there are any duplicate tags and return them."""
    tag_counts = {}
    for tag in tags:
        tag_counts[tag] = tag_counts.get(tag, 0) + 1
    
    duplicates = {tag: count for tag, count in tag_counts.items() if count > 1}
    return duplicates


def replace_untagged(file_path, placeholder, length, charset):
    """Replace all placeholder strings with unique tags."""
    # Read the file
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Extract existing tags (as list to detect duplicates)
    existing_tags_list = extract_existing_tags(content, length, charset)
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
    
    # Find all placeholder occurrences with context
    placeholder_quoted = f'"{placeholder}"'
    lines = content.split('\n')
    untagged_lines = []
    
    for line_num, line in enumerate(lines, 1):
        if placeholder_quoted in line:
            # Extract function/constant name from the line
            # Look for pattern like: NSString * const MSID_TELEMETRY_TAG_SOMETHING = @"UNTAGGED";
            match = re.search(r'MSID_TELEMETRY_TAG_(\w+)\s*=', line)
            func_name = match.group(1) if match else "unknown"
            untagged_lines.append((line_num, func_name, line.strip()))
    
    untagged_count = len(untagged_lines)
    print(f"\nFound {untagged_count} {placeholder} entries to replace:")
    
    if untagged_count == 0:
        print(f"No {placeholder} entries found. Nothing to do.")
        return
    
    # Show what will be replaced
    for line_num, func_name, line in untagged_lines:
        print(f"  Line {line_num}: {func_name}")
    
    # Generate new unique tags
    print(f"\nGenerating {untagged_count} unique tags...")
    new_tags = []
    for i in range(untagged_count):
        tag = generate_tag(existing_tags_set | set(new_tags), length, charset)
        new_tags.append(tag)
    
    # Replace placeholder one by one to ensure each gets a unique tag
    modified_content = content
    replacements = []
    for i, tag in enumerate(new_tags):
        modified_content = modified_content.replace(placeholder_quoted, f'"{tag}"', 1)
        line_num, func_name, _ = untagged_lines[i]
        replacements.append((line_num, func_name, placeholder, tag))
    
    # Verify all replacements were made
    remaining_untagged = modified_content.count(placeholder_quoted)
    if remaining_untagged > 0:
        print(f"Warning: {remaining_untagged} {placeholder} entries remain!")
        return
    
    # Write back to file
    with open(file_path, 'w') as f:
        f.write(modified_content)
    
    # Show what was replaced
    print(f"\n✅ Successfully replaced {untagged_count} {placeholder} entries:\n")
    for line_num, func_name, old_tag, new_tag in replacements:
        print(f"  Line {line_num}: {func_name}")
        print(f"    {old_tag} → {new_tag}")
    
    print(f"\nNew tags generated: {', '.join(new_tags)}")


def main():
    parser = argparse.ArgumentParser(
        description='Replace placeholder strings in MSIDExecutionFlowConstants.m with unique tags'
    )
    
    # Default path
    default_path = Path(__file__).parent.parent / "IdentityCore/src/telemetry/execution_flow/MSIDExecutionFlowConstants.m"
    
    parser.add_argument(
        'file_path',
        nargs='?',
        default=str(default_path),
        help='Path to the file to process (default: MSIDExecutionFlowConstants.m)'
    )
    parser.add_argument(
        '--placeholder',
        default='UNTAGGED',
        help='Placeholder string to replace (default: UNTAGGED)'
    )
    parser.add_argument(
        '--length',
        type=int,
        default=5,
        help='Length of generated tags (default: 5)'
    )
    parser.add_argument(
        '--charset',
        default='abcdefghijklmnopqrstuvwxyz123456789',
        help='Character set for generating tags (default: a-z and 1-9)'
    )
    
    args = parser.parse_args()
    
    file_path = Path(args.file_path)
    
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)
    
    print(f"Processing file: {file_path}")
    print(f"Placeholder: {args.placeholder}")
    print(f"Tag length: {args.length}")
    print(f"Character set: {args.charset}")
    print("-" * 60)
    
    replace_untagged(file_path, args.placeholder, args.length, args.charset)


if __name__ == "__main__":
    main()
