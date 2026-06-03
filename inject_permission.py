import os

manifest_path = "android/app/src/main/AndroidManifest.xml"
if os.path.exists(manifest_path):
    with open(manifest_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    permissions = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>',
        '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>'
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

    # ── MainActivity FlutterFragmentActivity rewrite for local_auth ──────────
    main_activity_found = False
    for root, dirs, files in os.walk("android"):
        for file in files:
            if file == "MainActivity.kt":
                activity_path = os.path.join(root, file)
                with open(activity_path, "r", encoding="utf-8") as af:
                    act_content = af.read()
                
                # Check and perform replacing
                if "import io.flutter.embedding.android.FlutterActivity" in act_content:
                    act_content = act_content.replace(
                        "import io.flutter.embedding.android.FlutterActivity",
                        "import io.flutter.embedding.android.FlutterFragmentActivity"
                    )
                    act_content = act_content.replace(
                        ": FlutterActivity()",
                        ": FlutterFragmentActivity()"
                    )
                    with open(activity_path, "w", encoding="utf-8") as af:
                        af.write(act_content)
                    print(f"✅ Successfully converted {file} to FlutterFragmentActivity!")
                    main_activity_found = True
                    break
        if main_activity_found:
            break
else:
    print("❌ AndroidManifest.xml not found")
    exit(1)
