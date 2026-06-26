import os
import re
import sys

# Force UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

lib_dir = "E:\\vista\\lib"
features_dir = os.path.join(lib_dir, "features")

# We want to forbid hardcoded `Color(0x...)` in UI files outside of the theme.
# And strongly discourage Colors.white/Colors.black outside of text colors on colored backgrounds.

color_regex = re.compile(r"Color\(0x[0-9a-fA-F]{8}\)")
colors_white_black_regex = re.compile(r"Colors\.(white|black)(?!\s*\.\s*with)") # Allow withOpacity / withValues sometimes, but mostly flag them.

exceptions = [
    "app_theme.dart",
    "chat_theme.dart",
    "vista_motion.dart",
]

issues_found = 0

print("Running Hardcoded Colors Audit...")

for root, dirs, files in os.walk(features_dir):
    for file in files:
        if file.endswith(".dart") and file not in exceptions:
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            for line_num, line in enumerate(lines, 1):
                # Check for raw hex colors
                if color_regex.search(line):
                    # We will just warn for now, since we did a massive sweep, 
                    # but some might be legitimate (e.g. specific feature brand colors).
                    # Actually, the goal is to eradicate them.
                    print(f"[WARN] Hardcoded Color(0x...) found in {filepath}:{line_num}")
                    print(f"       {line.strip()}")
                    issues_found += 1

                # We can optionally flag Colors.white/black, but there are hundreds of safe usages (text on primary buttons).
                # To reduce noise, we only do raw hex colors for the strict audit.

if issues_found > 0:
    print(f"\nAudit failed! Found {issues_found} hardcoded hex colors.")
    print("Please use AppColors or Theme.of(context).colorScheme instead.")
    sys.exit(1)
else:
    print("\nAudit passed! No hardcoded hex colors found.")
    sys.exit(0)
