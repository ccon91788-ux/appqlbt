"""Vá thư mục android/ do `flutter create` sinh ra: quyền, receiver thông báo, desugaring, compileSdk."""
import pathlib
import re

COMPILE_SDK = "36"

m = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = m.read_text(encoding="utf-8")
perms = (
    '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
    '<uses-permission android:name="android.permission.INTERNET"/>\n'
    '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n'
    '<uses-permission android:name="android.permission.VIBRATE"/>\n'
    '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
    '<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>\n'
)
recv = (
    '<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>\n'
    '<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">'
    '<intent-filter>'
    '<action android:name="android.intent.action.BOOT_COMPLETED"/>'
    '<action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>'
    '<action android:name="android.intent.action.QUICKBOOT_POWERON"/>'
    '<action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>'
    '</intent-filter></receiver>\n'
    '<provider android:name="sk.fourq.otaupdate.OtaUpdateFileProvider" '
    'android:authorities="${applicationId}.ota_update_provider" '
    'android:exported="false" android:grantUriPermissions="true">'
    '<meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/filepaths"/>'
    '</provider>\n'
)
xml_dir = pathlib.Path("android/app/src/main/res/xml")
xml_dir.mkdir(parents=True, exist_ok=True)
(xml_dir / "filepaths.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<paths xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <files-path name="internal_apk_storage" path="ota_update/"/>\n'
    '</paths>\n',
    encoding="utf-8",
)
if "POST_NOTIFICATIONS" not in s:
    s = s.replace("<application", perms + "<application", 1)
    s = s.replace("</application>", recv + "</application>", 1)
VIEW_INTENT = '<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>'
if "android.scheme" not in s and 'android:scheme="https"' not in s:
    if "</queries>" in s:
        s = s.replace("</queries>", VIEW_INTENT + "</queries>", 1)
    else:
        s = s.replace("<application", "<queries>" + VIEW_INTENT + "</queries>\n<application", 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="LifeSync"', s, count=1)
m.write_text(s, encoding="utf-8")

for name in ("build.gradle.kts", "build.gradle"):
    f = pathlib.Path("android/app") / name
    if not f.exists():
        continue
    g = f.read_text(encoding="utf-8")
    # Nâng compileSdk (thư viện AndroidX mới yêu cầu 36+)
    g = re.sub(
        r"compileSdk(?:Version)?(\s*=\s*|\s+)flutter\.compileSdkVersion",
        r"compileSdk\g<1>" + COMPILE_SDK,
        g,
    )
    if "esugaring" not in g:
        if name.endswith(".kts"):
            g = g.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
            g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        else:
            g = g.replace("compileOptions {", "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
            g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
    f.write_text(g, encoding="utf-8")
    print("--- " + name)
    for line in g.splitlines():
        if "compileSdk" in line or "esugaring" in line:
            print(line.strip())
    break
print("Android patched")

# --- Ép mọi plugin (subproject) dùng compileSdk 36 ---
KTS_HOOK = """subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android")
        if (ext != null) {
            val m = ext.javaClass.methods.firstOrNull {
                it.name == "compileSdkVersion" && it.parameterTypes.size == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType
            }
            m?.invoke(ext, %s)
        }
    }
}

""" % COMPILE_SDK
GROOVY_HOOK = """subprojects {
    afterEvaluate { p ->
        if (p.hasProperty('android')) {
            p.android.compileSdkVersion %s
        }
    }
}

""" % COMPILE_SDK

for name, hook in (("build.gradle.kts", KTS_HOOK), ("build.gradle", GROOVY_HOOK)):
    f = pathlib.Path("android") / name
    if not f.exists():
        continue
    g = f.read_text(encoding="utf-8")
    if "compileSdkVersion" not in g:
        i = g.find("subprojects {")
        # Phải đăng ký TRƯỚC khối evaluationDependsOn(":app")
        g = (g[:i] + hook + g[i:]) if i >= 0 else (g + "\n" + hook)
        f.write_text(g, encoding="utf-8")
    print("root " + name + " patched")
    break

# --- Ký bản release bằng khóa cố định (nếu workflow đã tạo android/key.properties) ---
if pathlib.Path("android/key.properties").exists():
    KTS_SIGN = """    signingConfigs {
        create("release") {
            val p = java.util.Properties()
            p.load(java.io.FileInputStream(rootProject.file("key.properties")))
            keyAlias = p["keyAlias"] as String
            keyPassword = p["keyPassword"] as String
            storeFile = file(p["storeFile"] as String)
            storePassword = p["storePassword"] as String
        }
    }
"""
    GROOVY_SIGN = """    signingConfigs {
        release {
            def p = new Properties()
            p.load(new FileInputStream(rootProject.file("key.properties")))
            keyAlias p['keyAlias']
            keyPassword p['keyPassword']
            storeFile file(p['storeFile'])
            storePassword p['storePassword']
        }
    }
"""
    for name, block in (("build.gradle.kts", KTS_SIGN), ("build.gradle", GROOVY_SIGN)):
        f = pathlib.Path("android/app") / name
        if not f.exists():
            continue
        g = f.read_text(encoding="utf-8")
        if "signingConfigs {" not in g:
            g = g.replace("buildTypes {", block + "\n    buildTypes {", 1)
        g = g.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        g = g.replace("signingConfigs.debug", "signingConfigs.release")
        if "import java.io.FileInputStream" not in g and name == "build.gradle":
            g = "import java.io.FileInputStream\n" + g
        f.write_text(g, encoding="utf-8")
        print("release signing configured in " + name)
        break
else:
    pass
if not pathlib.Path("android/key.properties").exists():
    print("WARNING: no release key, APK will use a temporary debug key")
