#!/bin/bash
set -euo pipefail
umask 077
config_dir="$HOME/.hammerspoon"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --config-dir) [ "$#" -ge 2 ] || exit 2; config_dir="$2"; shift 2 ;;
    *) echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done
[ -n "$config_dir" ] || exit 2
target="$config_dir/iwork-work"
init_file="$config_dir/init.lua"
[ ! -L "$target" ] && [ ! -L "$init_file" ] || { echo '심볼릭 링크 설정은 수동으로 해제하세요.' >&2; exit 1; }
[ -d "$config_dir" ] || { echo '설치된 설정이 없습니다.'; exit 0; }
scratch="$(mktemp -d "$config_dir/.iwork-uninstall.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
if [ -f "$init_file" ]; then
  awk '
    $0=="-- BEGIN IWORK WORK PANEL" { if (inside) exit 2; inside=1; starts++; next }
    $0=="-- END IWORK WORK PANEL" { if (!inside) exit 2; inside=0; ends++; next }
    !inside { print }
    END { if (inside || starts!=ends) exit 2 }
  ' "$init_file" > "$scratch/init.lua" || { echo '설치 블록을 확인하세요. 원본은 유지했습니다.' >&2; exit 1; }
fi
backup_dir="$config_dir/.iwork-work-backups/uninstall-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup_dir"
if [ -f "$init_file" ]; then cp -p "$init_file" "$backup_dir/init.lua"; cp "$scratch/init.lua" "$init_file"; fi
if [ -d "$target" ]; then mv "$target" "$backup_dir/panel"; fi
echo "편집 패널 연결 해제 완료. 파일과 개인 설정은 $backup_dir 에 보관했습니다."
echo 'Hammerspoon에서 Reload Config를 누르세요.'
