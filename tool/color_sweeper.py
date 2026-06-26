import os
import re

lib_dir = "E:\\vista\\lib"

color_map = {
    # Phase 1
    "Color(0xFF6366F1)": "AppColors.primary",
    "Color(0xFF8B5CF6)": "AppColors.secondary",
    "Color(0xFFEC4899)": "AppColors.accent",
    "Color(0xFF10B981)": "AppColors.success",
    "Color(0xFF34D399)": "AppColors.successDark",
    "Color(0xFFF59E0B)": "AppColors.warning",
    "Color(0xFFFBBF24)": "AppColors.warningDark",
    "Color(0xFFEF4444)": "AppColors.error",
    "Color(0xFFF87171)": "AppColors.errorDark",
    "Color(0xFF3B82F6)": "AppColors.info",
    "Color(0xFF22C55E)": "AppColors.online",
    "Color(0xFF4ADE80)": "AppColors.onlineDark",
    "Color(0xFFEEF2FF)": "AppColors.primaryLight",
    "Color(0xFF4F46E5)": "AppColors.primaryDark",

    # Phase 2 (Top remaining)
    "Color(0xFF1C1C1E)": "AppColors.darkSurfaceVariant",
    "Color(0xFF2C2C2E)": "AppColors.darkBorder",
    "Color(0xFF1A1A1A)": "AppColors.darkSurface",
    "Color(0xFF1E1E1E)": "AppColors.darkSurface",
    "Color(0xFF2A2A2A)": "AppColors.darkSurface",
    "Color(0xFF3A3A3A)": "AppColors.darkSurfaceVariant",
    
    "Color(0xFF4A80F0)": "AppColors.primary", 
    "Color(0xFF8E5CF7)": "AppColors.secondary", 
    "Color(0xFFDD2A7B)": "AppColors.accent", 
    "Color(0xFFE91E63)": "AppColors.accent",
    "Color(0xFF8774E1)": "AppColors.primaryDark",
    "Color(0xFF2196F3)": "AppColors.info",
    "Color(0xFFFFD700)": "AppColors.warning",
    "Color(0xFFFF9800)": "AppColors.warning",
    "Color(0xFF9C27B0)": "AppColors.secondary",
    "Color(0xFF4CAF50)": "AppColors.success",
    "Color(0xFF6C63FF)": "AppColors.primary",
    "Color(0xFFF5F5F5)": "AppColors.lightSurfaceVariant",

    # Phase 3 (More specific dark backgrounds)
    "Color(0xFF0F0F0F)": "AppColors.darkBackground",
    "Color(0xFF17212B)": "AppColors.darkBackground",
    "Color(0xFF232E3C)": "AppColors.darkSurface",
    "Color(0xFF303D4F)": "AppColors.darkBorder",
    "Color(0xFFE4E6E9)": "AppColors.lightBorder",
    "Color(0xFF2A4157)": "AppColors.darkSurfaceVariant",
    "Color(0xFF6C9BCF)": "AppColors.primaryLight",
    "Color(0xFF3D5A80)": "AppColors.darkSurfaceVariant",
    "Color(0xFF293241)": "AppColors.darkElevated",
    "Color(0xFF4A7C9B)": "AppColors.primaryDark",
    "Color(0xFF2A3646)": "AppColors.darkSurfaceVariant",
    "Color(0xFF334155)": "AppColors.darkSurfaceVariant",
    "Color(0xFF0D1117)": "AppColors.darkBackground",
    "Color(0xFF161B22)": "AppColors.darkSurface",
    "Color(0xFFF8FAFC)": "AppColors.lightBackground",
    "Color(0xFFE2E8F0)": "AppColors.lightBorder",
    "Color(0xFF14141A)": "AppColors.darkSurface",
    "Color(0xFF0F0F13)": "AppColors.darkBackground",

    # And some white/black hardcodes 
    "Color(0xFFFFFFFF)": "Colors.white",
    "Color(0xFF000000)": "Colors.black",
}

primary_gradient_regex = r"LinearGradient\s*\(\s*colors:\s*\[\s*(?:Color\(0xFF6366F1\)|AppColors\.primary(?:Start)?)\s*,\s*(?:Color\(0xFF8B5CF6\)|AppColors\.primaryEnd|AppColors\.secondary)\s*\][^)]*\)"
hero_gradient_regex = r"LinearGradient\s*\(\s*colors:\s*\[\s*Color\(0xFF6366F1\)\s*,\s*Color\(0xFF8B5CF6\)\s*,\s*Color\(0xFFEC4899\)\s*\][^)]*\)"

import_stmt = "import 'package:Vista/core/theme/app_theme.dart';"

def process_file(filepath):
    if "app_theme.dart" in filepath or "chat_theme.dart" in filepath:
        return 

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    content = re.sub(primary_gradient_regex, "AppColors.primaryGradient", content, flags=re.DOTALL)
    content = re.sub(hero_gradient_regex, "AppColors.heroGradient", content, flags=re.DOTALL)

    for hex_color, app_color in color_map.items():
        # Handle const Color(0xFF...) becoming const AppColors... which is invalid if AppColors isn't a class with const, but it is.
        # Actually in Dart, if we replace `const Color(0xFF...)` with `const AppColors.primary`, it's valid if AppColors.primary is a const.
        # Sometimes it's better to remove the explicit const before Color if it causes issues, but for now we'll just do the replacement.
        
        # Replace `const Color` to `AppColors` will leave `const AppColors` which is fine
        content = content.replace(hex_color, app_color)
        content = content.replace(hex_color.replace('xFF', 'xff').lower(), app_color)

    if content != original_content:
        if "AppColors." in content and import_stmt not in content:
            last_import_idx = content.rfind("import '")
            if last_import_idx != -1:
                end_of_line = content.find("\n", last_import_idx)
                content = content[:end_of_line+1] + import_stmt + "\n" + content[end_of_line+1:]
            else:
                content = import_stmt + "\n\n" + content
                
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            process_file(os.path.join(root, file))

print("Phase 2 Color sweep complete.")
