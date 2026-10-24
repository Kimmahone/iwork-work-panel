#!/bin/bash
set -euo pipefail
umask 077
bundle_dir="$(cd "$(dirname "$0")" && pwd)"
config_dir="$HOME/.hammerspoon"
open_app=true
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config-dir) [ "$#" -ge 2 ] || exit 2; config_dir="$2"; shift 2 ;;
    --no-open) open_app=false; shift ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done
[ -n "$config_dir" ] || exit 2
target="$config_dir/iwork-work"
init_file="$config_dir/init.lua"
begin_marker='-- BEGIN IWORK WORK PANEL'
end_marker='-- END IWORK WORK PANEL'
[ ! -L "$target" ] && [ ! -L "$init_file" ] || { echo '심볼릭 링크 설정은 README의 수동 설치를 사용하세요.' >&2; exit 1; }
[ -f "$bundle_dir/SHA256SUMS" ] || { echo '완성된 Release ZIP을 사용하세요.' >&2; exit 1; }
(cd "$bundle_dir" && shasum -a 256 -c SHA256SUMS >/dev/null)
while IFS= read -r name; do
  case "$name" in ''|*/*|..*) echo '설치 파일 목록 오류' >&2; exit 1 ;; esac
  [ -f "$bundle_dir/panel/$name" ] || exit 1
done < "$bundle_dir/payload-files.txt"
mkdir -p "$config_dir"
scratch="$(mktemp -d "$config_dir/.iwork-install.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
filter_block() {
  awk -v first="$begin_marker" -v last="$end_marker" '
    $0==first { if (inside) exit 2; inside=1; starts++; next }
    $0==last { if (!inside) exit 2; inside=0; ends++; next }
    !inside { print }
    END { if (inside || starts!=ends) exit 2 }
  ' "$1"
}
if [ -f "$init_file" ]; then
  filter_block "$init_file" > "$scratch/existing.lua" || { echo '기존 설치 블록을 확인하세요. 원본 설정은 유지했습니다.' >&2; exit 1; }
else
  : > "$scratch/existing.lua"
fi
cat > "$scratch/init.lua" <<'LUA'
-- BEGIN IWORK WORK PANEL
dofile(hs.configdir .. "/iwork-work/main.lua")
-- END IWORK WORK PANEL
LUA
cat "$scratch/existing.lua" >> "$scratch/init.lua"
backup_dir="$config_dir/.iwork-work-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup_dir"
if [ -f "$init_file" ]; then cp -p "$init_file" "$backup_dir/init.lua"; fi
if [ -d "$target" ]; then cp -R "$target" "$backup_dir/panel"; fi
mkdir -p "$target"
while IFS= read -r name; do cp "$bundle_dir/panel/$name" "$target/$name"; done < "$bundle_dir/payload-files.txt"
cp "$scratch/init.lua" "$init_file"
echo "설치 완료: $target"
echo "기존 설정 백업: $backup_dir"
echo 'Hammerspoon 메뉴에서 Reload Config를 누르고 손쉬운 사용 권한을 허용하세요.'
if [ "$open_app" = true ] && [ "$(uname -s)" = Darwin ]; then
  if [ -d /Applications/Hammerspoon.app ]; then open /Applications/Hammerspoon.app; else echo '먼저 https://www.hammerspoon.org/ 에서 Hammerspoon을 설치하세요.'; fi
fi
