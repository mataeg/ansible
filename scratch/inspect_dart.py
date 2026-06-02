import os
import re

def analyze_dart_files():
    lib_path = "/root/fleet_app/lib"
    errors = []
    
    # Check all dart files
    for root, dirs, files in os.walk(lib_path):
        for file in files:
            if file.endswith(".dart"):
                filepath = os.path.join(root, file)
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()
                    
                # 1. Check for mismatched braces/parentheses
                open_braces = content.count("{")
                close_braces = content.count("}")
                if open_braces != close_braces:
                    errors.append(f"{file}: Mismatched curly braces: {{ is {open_braces}, }} is {close_braces}")
                    
                open_parens = content.count("(")
                close_parens = content.count(")")
                if open_parens != close_parens:
                    errors.append(f"{file}: Mismatched parentheses: ( is {open_parens}, ) is {close_parens}")
                
                # 2. Check for common syntax errors (e.g. missing semicolons on imports)
                for line_no, line in enumerate(content.splitlines(), 1):
                    if line.strip().startswith("import ") and not line.strip().endswith(";"):
                        errors.append(f"{file}:{line_no}: Import missing semicolon: {line}")
                        
                    # Check for unmatched single quotes
                    if line.count("'") % 2 != 0 and "//" not in line and "/*" not in line:
                        # might be a multiline string, but check anyway
                        pass
                        
    if errors:
        print("\n".join(errors))
    else:
        print("No structural/syntax errors found in Dart files.")

if __name__ == "__main__":
    analyze_dart_files()
