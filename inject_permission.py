import os

manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    permissions = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>'
    ]
    
    modified = False
    for permission_tag in permissions:
        if permission_tag not in content:
            if "<manifest" in content:
                idx = content.find('>', content.find("<manifest"))
                if idx != -1:
                    content = content[:idx+1] + "\n    " + permission_tag + content[idx+1:]
                    modified = True
                else:
                    print("❌ Could not find closing '>' for manifest tag")
                    exit(1)
            else:
                print("❌ Could not find manifest tag")
                exit(1)
    
    if modified:
        with open(manifest_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("✅ Permissions successfully injected!")
    else:
        print("⚠️ Permissions already present")
else:
    print("❌ AndroidManifest.xml not found")
    exit(1)
