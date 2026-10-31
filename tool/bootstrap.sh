#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter not found. Use the Dev Container or install Flutter 3.47.2.' >&2
  exit 1
fi

required_flutter='3.47.2'
current_flutter="$(flutter --version | head -n 1 | awk '{print $2}')"
if [[ "${current_flutter}" != "${required_flutter}" ]]; then
  echo "Expected Flutter ${required_flutter}, found ${current_flutter}." >&2
  exit 1
fi

needs_android=false
needs_web=false
if [[ ! -f android/app/build.gradle.kts && ! -f android/app/build.gradle ]]; then
  needs_android=true
elif [[ ! -f android/gradlew || ! -f android/gradle/wrapper/gradle-wrapper.jar ]]; then
  needs_android=true
fi
[[ -f web/index.html ]] || needs_web=true

if [[ "${needs_android}" == true || "${needs_web}" == true ]]; then
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' EXIT

  flutter create \
    --platforms=android,web \
    --org vn.edu.phenikaa \
    --project-name better_phenikaa_schedule \
    "${tmp_dir}/scaffold"

  if [[ "${needs_android}" == true ]]; then
    if [[ -d android/app/src ]]; then
      cp -R android/app/src "${tmp_dir}/preserved-app-src"
    fi
    if [[ -f android/app/build.gradle.kts ]]; then
      cp android/app/build.gradle.kts "${tmp_dir}/preserved-app-build.gradle.kts"
    fi
    rm -rf android
    cp -R "${tmp_dir}/scaffold/android" ./android
  fi

  if [[ "${needs_web}" == true ]]; then
    rm -rf web
    cp -R "${tmp_dir}/scaffold/web" ./web
  fi

  if [[ ! -f .metadata ]]; then
    cp "${tmp_dir}/scaffold/.metadata" ./.metadata
  fi
fi

# Better Phenikaa App compiles against Android API 37 because current
# flutter_secure_storage requires API 37 AAR metadata. AGP 9.1.1 supports
# API 37 while keeping the template's Gradle/JDK line intact.
if [[ -d android ]]; then
  python3 - <<'PY'
from pathlib import Path
import re

settings = Path('android/settings.gradle.kts')
if settings.exists():
    text = settings.read_text()
    text = re.sub(
        r'id\("com\.android\.application"\) version "[^"]+" apply false',
        'id("com.android.application") version "9.1.1" apply false',
        text,
        count=1,
    )
    settings.write_text(text)

app_kts = Path('android/app/build.gradle.kts')
if app_kts.exists():
    text = app_kts.read_text()
    text = re.sub(
        r'compileSdk\s*=\s*[^\n]+',
        'compileSdk = 37',
        text,
        count=1,
    )
    if 'androidx.work:work-runtime-ktx' not in text:
        dependencies = '''dependencies {
    implementation("androidx.work:work-runtime-ktx:2.11.2")
    testImplementation("junit:junit:4.13.2")
}

'''
        text = text.replace('android {', dependencies + 'android {', 1)
    app_kts.write_text(text)

app_groovy = Path('android/app/build.gradle')
if app_groovy.exists():
    text = app_groovy.read_text()
    text = re.sub(
        r'compileSdk(?:Version)?\s+[^\n]+',
        'compileSdk 37',
        text,
        count=1,
    )
    if 'androidx.work:work-runtime-ktx' not in text:
        dependencies = '''dependencies {
    implementation 'androidx.work:work-runtime-ktx:2.11.2'
    testImplementation 'junit:junit:4.13.2'
}

'''
        text = text.replace('android {', dependencies + 'android {', 1)
    app_groovy.write_text(text)
PY

  sdkmanager_bin=""
  if command -v sdkmanager >/dev/null 2>&1; then
    sdkmanager_bin="$(command -v sdkmanager)"
  elif [[ -n "${ANDROID_SDK_ROOT:-}" && -x "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" ]]; then
    sdkmanager_bin="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
  elif [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]]; then
    sdkmanager_bin="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
  fi

  if [[ -n "${sdkmanager_bin}" ]]; then
    yes | "${sdkmanager_bin}" --licenses >/dev/null 2>&1 || true
    "${sdkmanager_bin}" "cmdline-tools;latest" || true

    sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
    if [[ -n "${sdk_root}" && -x "${sdk_root}/cmdline-tools/latest/bin/sdkmanager" ]]; then
      sdkmanager_bin="${sdk_root}/cmdline-tools/latest/bin/sdkmanager"
    fi

    yes | "${sdkmanager_bin}" --licenses >/dev/null 2>&1 || true
    "${sdkmanager_bin}" "platforms;android-37.0" "build-tools;37.0.0"
  fi
fi

if [[ -d platform/android_widget/app ]]; then
  if [[ "${needs_android}" == true ]]; then
    cp -R platform/android_widget/app/. android/app/
    if [[ -d "${tmp_dir}/preserved-app-src" ]]; then
      cp -R "${tmp_dir}/preserved-app-src/." android/app/src/
    fi
    if [[ -f "${tmp_dir}/preserved-app-build.gradle.kts" ]]; then
      cp "${tmp_dir}/preserved-app-build.gradle.kts" android/app/build.gradle.kts
    fi
  fi

  python3 - <<'PY'
from pathlib import Path
import re

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text()

permission = '    <uses-permission android:name="android.permission.INTERNET" />\n'
if 'android.permission.INTERNET' not in text:
    text = text.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n' + permission,
        1,
    )

boot_permission = '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n'
if 'android.permission.RECEIVE_BOOT_COMPLETED' not in text:
    text = text.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n' + boot_permission,
        1,
    )

receiver = '''        <receiver
            android:name=".ScheduleWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/schedule_widget_info" />
        </receiver>
'''
if '.ScheduleWidgetProvider' not in text:
    text = text.replace('    </application>', receiver + '    </application>', 1)

service = '''        <service
            android:name=".ScheduleWidgetService"
            android:exported="false"
            android:permission="android.permission.BIND_REMOTEVIEWS" />
'''
if '.ScheduleWidgetService' not in text:
    text = text.replace('    </application>', service + '    </application>', 1)

activity = '''        <activity
            android:name=".WidgetDatePickerActivity"
            android:exported="false"
            android:theme="@android:style/Theme.Translucent.NoTitleBar" />
'''
if '.WidgetDatePickerActivity' not in text:
    text = text.replace('    </application>', activity + '    </application>', 1)

sync_receiver = '''        <receiver
            android:name=".DailySyncRescheduleReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.TIME_SET" />
                <action android:name="android.intent.action.TIMEZONE_CHANGED" />
            </intent-filter>
        </receiver>
'''
if '.DailySyncRescheduleReceiver' not in text:
    text = text.replace('    </application>', sync_receiver + '    </application>', 1)

day_receiver = '''        <receiver
            android:name=".WidgetDayChangeReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.DATE_CHANGED" />
                <action android:name="android.intent.action.TIME_SET" />
                <action android:name="android.intent.action.TIMEZONE_CHANGED" />
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
'''
if '.WidgetDayChangeReceiver' not in text:
    text = text.replace('    </application>', day_receiver + '    </application>', 1)

text = re.sub(
    r'android:label="[^"]*"',
    'android:label="Better Phenikaa App"',
    text,
    count=1,
)
text = re.sub(
    r'android:icon="[^"]*"',
    'android:icon="@mipmap/ic_launcher"',
    text,
    count=1,
)
text = re.sub(
    r'android:roundIcon="[^"]*"',
    'android:roundIcon="@mipmap/ic_launcher_round"',
    text,
    count=1,
)
if 'android:roundIcon=' not in text:
    text = text.replace(
        'android:icon="@mipmap/ic_launcher"',
        'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"',
        1,
    )
if 'android:allowBackup=' not in text:
    text = text.replace(
        '<application\n',
        '<application\n        android:allowBackup="false"\n',
        1,
    )
manifest.write_text(text)
PY
fi

flutter pub get

# flutter_inappwebview_android 1.1.3 still references the legacy default
# ProGuard file that recent Android Gradle Plugin versions reject for release
# builds. Patch the cached dependency reproducibly until upstream stable ships
# the same one-line migration.
inappwebview_gradle="${PUB_CACHE:-${HOME}/.pub-cache}/hosted/pub.dev/flutter_inappwebview_android-1.1.3/android/build.gradle"
if [[ -f "${inappwebview_gradle}" ]] && grep -q "getDefaultProguardFile('proguard-android.txt')" "${inappwebview_gradle}"; then
  sed -i "s/getDefaultProguardFile('proguard-android.txt')/getDefaultProguardFile('proguard-android-optimize.txt')/g" "${inappwebview_gradle}"
  echo 'Patched flutter_inappwebview_android release ProGuard compatibility.'
fi

echo 'Bootstrap complete.'
