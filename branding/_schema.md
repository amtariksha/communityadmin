# White-label branding — `branding/`

This directory drives the **build-time** white-label factory. Each
society that gets its own store listing has one folder here. The
common shared app uses `default/`.

## Layout

```
branding/
  default/            # the common shared app — committed
    brand.json
    logo.png          # in-app logo (splash / login / runtime fallback)
    app_icon.png      # launcher-icon source — 1024×1024, full-bleed
    splash.png        # native splash image
  <society-slug>/     # one folder per paying society
    brand.json  logo.png  app_icon.png  splash.png
```

## `brand.json`

| Key | Meaning |
|---|---|
| `slug` | Folder name; identifies the brand. |
| `appName` | Home-screen launcher label + in-app wordmark fallback. |
| `applicationId` | Android package ID. **Unique per store listing.** |
| `iosBundleId` | iOS bundle identifier. **Unique per store listing.** |
| `apiBaseUrl` | Backend instance this build targets. |
| `colors.primary` … | 6-digit hex (no `#`). Theme palette — baked into `BrandConfig`. |

## Applying a brand

```
dart run tool/apply_brand.dart <slug>      # codegen + assets + native patch
scripts/build_release.sh <slug> appbundle  # apply + flutter build, one shot
```

`apply_brand.dart`:
1. generates `lib/config/brand_config.dart`,
2. copies `logo/splash/app_icon` into `assets/branding/`,
3. patches the Android/iOS launcher name + package ID,
4. regenerates launcher icons + native splash (`--no-icons` to skip).

The generated `brand_config.dart` is committed with the `default`
brand, so the repo builds out of the box. Dedicated builds run the
script on a clean / CI checkout.

## Firebase (per dedicated build)

A unique `applicationId` / `iosBundleId` needs its own app registered
inside the **shared** Firebase project `communityos-9a54d`:

1. Firebase console → project `communityos-9a54d` → Add app → enter the
   new package name / bundle ID.
2. Download the refreshed `google-services.json` (it carries a `client`
   entry per package name — one file works for all) and
   `GoogleService-Info.plist`; replace `android/app/` + `ios/Runner/`.

Theme **colours**, the **launcher icon**, and the **package ID** are
build-time (this factory). The per-society **logo** and **display name**
shown *inside* a running app are runtime — set by the super admin and
fetched from the backend; they do not need a rebuild.
