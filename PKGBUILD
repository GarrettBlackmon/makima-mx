# Maintainer: Garrett Blackmon <garrett@blackmon.dev>
pkgname=makima-mx-git
_pkgname=makima-mx
pkgver=r4.8ebfcd6
pkgrel=1
pkgdesc="Quickshell GUI for makima — visual remapper for Logitech MX Master 3/3S"
arch=('any')
url="https://github.com/GarrettBlackmon/makima-mx"
license=('MIT')
depends=('quickshell' 'makima' 'bash' 'awk' 'systemd' 'python')
optdepends=(
    'dankmaterialshell: live Matugen theme colors'
    'hyprland: live active-application indicator'
)
makedepends=('git')
provides=("$_pkgname")
conflicts=("$_pkgname")
source=("$_pkgname::git+$url.git")
sha256sums=('SKIP')

pkgver() {
    cd "$_pkgname"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
}

package() {
    cd "$_pkgname"

    # QML + assets to /usr/share/makima-mx/
    install -d "$pkgdir/usr/share/$_pkgname/assets/fonts"
    install -m644 *.qml *.js qmldir "$pkgdir/usr/share/$_pkgname/"
    install -m644 assets/mouse.png       "$pkgdir/usr/share/$_pkgname/assets/"
    install -m644 assets/icon.svg        "$pkgdir/usr/share/$_pkgname/assets/"
    install -m644 assets/fonts/*.ttf     "$pkgdir/usr/share/$_pkgname/assets/fonts/"

    # Chord profile-switcher helper
    install -Dm755 scripts/chord-watch.py "$pkgdir/usr/share/$_pkgname/scripts/chord-watch.py"

    # Launcher in /usr/bin
    install -d "$pkgdir/usr/bin"
    cat > "$pkgdir/usr/bin/$_pkgname" <<'EOF'
#!/usr/bin/env bash
exec quickshell -p /usr/share/makima-mx/shell.qml "$@"
EOF
    chmod 755 "$pkgdir/usr/bin/$_pkgname"

    # .desktop
    install -d "$pkgdir/usr/share/applications"
    cat > "$pkgdir/usr/share/applications/$_pkgname.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=makima-mx
GenericName=Mouse Remapper
Comment=Visual remapper for Logitech MX Master 3/3S buttons
Exec=$_pkgname
Icon=$_pkgname
Terminal=false
Categories=Settings;HardwareSettings;Utility;
Keywords=mouse;remap;makima;logitech;mx master;binding;
StartupNotify=true
EOF

    # Icons (hicolor theme: scalable + common sizes)
    install -Dm644 assets/icon.svg     "$pkgdir/usr/share/icons/hicolor/scalable/apps/$_pkgname.svg"
    install -Dm644 assets/icon-256.png "$pkgdir/usr/share/icons/hicolor/256x256/apps/$_pkgname.png"
    install -Dm644 assets/icon-128.png "$pkgdir/usr/share/icons/hicolor/128x128/apps/$_pkgname.png"
    install -Dm644 assets/icon-64.png  "$pkgdir/usr/share/icons/hicolor/64x64/apps/$_pkgname.png"

    # Docs
    install -Dm644 README.md "$pkgdir/usr/share/doc/$_pkgname/README.md"
}
