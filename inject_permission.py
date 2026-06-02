import os

manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    permission_tag = '<uses-permission android:name="android.permission.INTERNET"/>'
    if permission_tag not in content:
        if "<manifest" in content:
            idx = content.find('>', content.find("<manifest"))
            if idx != -1:
                content = content[:idx+1] + "\n    " + permission_tag + content[idx+1:]
                with open(manifest_path, "w", encoding="utf-8") as f:
                    f.write(content)
                print("✅ Internet permission successfully injected!")
            else:
                print("❌ Could not find closing '>' for manifest tag")
                exit(1)
        else:
            print("❌ Could not find manifest tag")
            exit(1)
    else:
        print("⚠️ Internet permission already present")
else:
    print("❌ AndroidManifest.xml not found")
    exit(1)
