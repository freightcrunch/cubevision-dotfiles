#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  ranger — scope.sh (file preview handler)                            ║
# ║  Install to: ~/.config/ranger/scope.sh                               ║
# ╚══════════════════════════════════════════════════════════════════════╝
# Exit codes:
#   0  = preview shown, no caching
#   1  = no preview
#   2  = plain text preview
#   3  = fix width (for image previews)
#   4  = fix height
#   5  = image preview (with path in stdout)
#   6  = preview shown and cached
#   7  = do not cache

set -o noclobber -o noglob -o nounset -o pipefail
IFS=$'\n'

FILE_PATH="${1}"
PV_WIDTH="${2}"
PV_HEIGHT="${3}"
IMAGE_CACHE_PATH="${4}"
PV_IMAGE_ENABLED="${5}"

FILE_EXTENSION="${FILE_PATH##*.}"
FILE_EXTENSION_LOWER="$(printf "%s" "${FILE_EXTENSION}" | tr '[:upper:]' '[:lower:]')"
MIMETYPE="$(file --dereference --brief --mime-type -- "${FILE_PATH}")"

handle_extension() {
    case "${FILE_EXTENSION_LOWER}" in
        # Archive
        a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|\
        rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip)
            atool --list -- "${FILE_PATH}" && exit 5
            bsdtar --list --file "${FILE_PATH}" && exit 5
            exit 1 ;;
        rar)
            unrar lt -p- -- "${FILE_PATH}" && exit 5
            exit 1 ;;
        7z)
            7z l -p -- "${FILE_PATH}" && exit 5
            exit 1 ;;

        # PDF
        pdf)
            pdftotext -l 10 -nopgbrk -q -- "${FILE_PATH}" - | \
                fmt -w "${PV_WIDTH}" && exit 5
            mutool draw -F txt -i -- "${FILE_PATH}" 1-10 | \
                fmt -w "${PV_WIDTH}" && exit 5
            exit 1 ;;

        # JSON
        json)
            python3 -m json.tool -- "${FILE_PATH}" && exit 5
            jq --color-output . "${FILE_PATH}" && exit 5
            exit 2 ;;

        # Torrent
        torrent)
            transmission-show -- "${FILE_PATH}" && exit 5
            exit 1 ;;

        # OpenDocument
        odt|ods|odp|sxw)
            odt2txt "${FILE_PATH}" && exit 5
            pandoc -s -t plain -- "${FILE_PATH}" && exit 5
            exit 1 ;;

        # XLSX
        xlsx)
            xlscat -i "${FILE_PATH}" && exit 5
            exit 1 ;;

        # Markdown
        md)
            glow -s dark -w "${PV_WIDTH}" "${FILE_PATH}" && exit 5
            exit 2 ;;
    esac
}

handle_mime() {
    case "${MIMETYPE}" in
        # Text
        text/* | */xml | */json | */javascript | */x-ndjson)
            if command -v bat &>/dev/null; then
                bat --color=always --style=plain \
                    --line-range=:200 \
                    --terminal-width="${PV_WIDTH}" \
                    -- "${FILE_PATH}" && exit 5
            fi
            exit 2 ;;

        # Image
        image/*)
            local orientation
            orientation="$(identify -format '%[EXIF:Orientation]\n' -- "${FILE_PATH}" 2>/dev/null)"
            if [[ -n "$orientation" && "$orientation" != 1 ]]; then
                convert -- "${FILE_PATH}" -auto-orient "${IMAGE_CACHE_PATH}" && exit 6
            fi
            exit 7 ;;

        # Video
        video/*)
            ffmpegthumbnailer -i "${FILE_PATH}" -o "${IMAGE_CACHE_PATH}" -s 0 && exit 6
            exit 1 ;;

        # Audio
        audio/*)
            mediainfo "${FILE_PATH}" && exit 5
            exit 1 ;;
    esac
}

handle_extension
handle_mime
exit 1
