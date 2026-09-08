# Leader first run

## 1. Mở môi trường chuẩn

Khuyến nghị mở repo bằng Codespaces/Dev Container. Container pin Flutter 3.47.2 + Dart 3.13 + JDK 17.

```bash
bash tool/bootstrap.sh
bash tool/quality.sh
```

`bootstrap.sh` tự sinh `android/`, `web/`, `.metadata` khi chưa có và chạy `flutter pub get`.

## 2. File nên commit sau lần bootstrap đầu

Sau khi kiểm tra build thành công, Lead có thể commit platform scaffold và `pubspec.lock` để tất cả thành viên dùng đúng transitive dependency:

```bash
git add android web .metadata pubspec.lock
git commit -m "chore: pin generated flutter platform scaffold"
```

Không commit `android/local.properties` hoặc key ký app.

## 3. Quality gate

```bash
bash tool/quality.sh
flutter build apk --debug
```

## 4. Branch policy nên bật trên GitHub

Cho `main` và `develop`:

- Require pull request before merging.
- Require CI status check.
- Block force push.
- Require conversation resolution.

`main` chỉ nhận thay đổi đã qua `develop`, trừ hotfix do Lead quản lý.

## 5. Contract review

Bất kỳ PR nào sửa `lib/core/contracts/` phải được Lead và ít nhất một consumer của contract review. Điều này giúp TV1/TV3 thay implementation mà TV2/TV4 không phải sửa dây chuyền.

## 6. Mobile test

Codespaces phù hợp để analyze/test/build APK và chạy Flutter Web preview; không coi web preview là thay thế test Android thật. APK từ workflow `Build APK` dùng để cài lên máy Android test.
