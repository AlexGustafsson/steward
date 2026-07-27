#!/usr/bin/env bash

BASE_PATH="$1"
DRY_RUN=1
SOURCE=DB
DURATION_FUZZINESS_SECONDS=2

touch lrclib_ul lrclib_sl
function cleanup {
	rm lrclib_ul lrclib_sl 2>/dev/null || true
}
trap cleanup EXIT

# SEE: https://github.com/tranxuanthang/lrclib/blob/ab7ce79d084d6f3cf8852c1f501b587aba900fff/server/src/utils.rs#L11
function prepare_string() {
	echo -n "$1" | tr '`~!@#$%^&*()_|+-=?;:",.‐<>{}[]\\/\n' ' ' | tr -d "'’" | iconv -c -s -f utf8 -t ascii//TRANSLIT | tr '[:upper:]' '[:lower:]' | sed -e 's/  \+/ /g' -e 's/^ \+//' -e 's/ \+$//'
}

function lrclib_search() {
	api="$1"
	track_name="$2"
	artist_name="$3"
	album_name="$4"
	duration="$5"

	curl --silent --get "$api/api/search" \
		-H "User-Agent: github.com/alexgustafsson/steward" \
		--data-urlencode "track_name=$track_name" \
		--data-urlencode "artist_name=$artist_name" \
		--data-urlencode "album_name=$album_name" | jq -rc ".[] | select(.duration > $((duration - DURATION_FUZZINESS_SECONDS)) and .duration < $((duration + DURATION_FUZZINESS_SECONDS)))"
}

function get_lyrics_api() {
	track_name="$1"
	artist_name="$2"
	album_name="$3"
	duration="$4"

	matches="$(lrclib_search "https://api.lrcmux.dev/compat/lrclib" "$track_name" "$artist_name" "$album_name" "$duration")"
	if [[ -z "$matches" ]]; then
		return
	fi

	unsynced_lyrics="$(jq -c '.plainLyrics | select(. != null)' <<<"$matches" | head -1)"
	unsynced_lyrics="${unsynced_lyrics:-\"\"}"

	synced_lyrics="$(jq -c '.syncedLyrics | select(. != null)' <<<"$matches" | head -1)"
	synced_lyrics="${synced_lyrics:-\"\"}"

	jq -rcn \
		--argjson plain_lyrics "$unsynced_lyrics" \
		--argjson synced_lyrics "$synced_lyrics" \
		'{plain_lyrics: $plain_lyrics, synced_lyrics: $synced_lyrics}'
}

function get_lyrics_db() {
	track_name="$(prepare_string "$1")"
	artist_name="$(prepare_string "$2")"
	album_name="$(prepare_string "$3")"
	duration="$4"

	cat <<EOF | sqlite3 -json lrclib.sqlite3 | jq '.[0]'
.param set :track_name '$track_name'
.param set :artist_name '$artist_name'
.param set :album_name '$album_name'
.param set :min_duration '$((duration - 2))'
.param set :max_duration '$((duration + 2))'

SELECT
  lyrics.plain_lyrics,
  lyrics.synced_lyrics
FROM tracks
LEFT JOIN lyrics ON tracks.last_lyrics_id = lyrics.id
WHERE
  (
    tracks.name_lower = :track_name
    AND tracks.artist_name_lower = :artist_name
    AND tracks.duration >= :min_duration
    AND tracks.duration <= :max_duration
  )
  OR
  (
    tracks.name_lower = :track_name
    AND tracks.album_name_lower = :album_name
    AND tracks.duration >= :min_duration
    AND tracks.duration <= :max_duration
  )
ORDER BY (lyrics.synced_lyrics IS NOT NULL) DESC, tracks.id
LIMIT 1;
EOF
}

function get_lyrics() {
	if [[ "$SOURCE" = "API" ]]; then
		get_lyrics_api "$@"
	elif [[ "$SOURCE" = "DB" ]]; then
		get_lyrics_db "$@"
	fi
}

total_analyzed=0
total_skipped=0
total_patched=0
total_fixed=0
while read -r file; do
	total_analyzed=$((total_analyzed + 1))

	fixed=0
	skipped=0
	# > 5 to keep some buffer for obviously malformed lyrics
	synced_lyrics="$(metaflac --show-tag=LYRICS "$file" | cut -d= -f2 | wc -c)"
	if [[ "$synced_lyrics" -gt 0 ]]; then
		if [[ "$synced_lyrics" -gt 5 ]]; then
			skipped=1
		else
			fixed=1
			if [[ -z "$DRY_RUN" ]]; then
				metaflac --preserve-modtime --remove-tag=LYRICS "$file"
			else
				echo metaflac --preserve-modtime --remove-tag=LYRICS "$file"
			fi
		fi
	fi

	# > 5 to keep some buffer for obviously malformed lyrics
	unsynced_lyrics="$(metaflac --show-tag=UNSYNCEDLYRICS "$file" | cut -d= -f2 | wc -c)"
	if [[ "$unsynced_lyrics" -gt 0 ]]; then
		if [[ "$unsynced_lyrics" -gt 5 ]]; then
			skipped=1
		else
			fixed=1
			if [[ -z "$DRY_RUN" ]]; then
				metaflac --preserve-modtime --remove-tag=UNSYNCEDLYRICS "$file"
			else
				echo metaflac --preserve-modtime --remove-tag=UNSYNCEDLYRICS "$file"
			fi
		fi
	fi

	total_skipped=$((total_skipped + skipped))
	total_fixed=$((total_fixed + fixed))

	if [[ $skipped -gt 0 ]]; then
		continue
	fi

	artist_name="$(metaflac --show-tag=ARTIST "$file" | cut -d= -f2)"
	track_name="$(metaflac --show-tag=TITLE "$file" | cut -d= -f2)"
	album_name="$(metaflac --show-tag=ALBUM "$file" | cut -d= -f2)"
	duration="$(metaflac --show-total-samples --show-sample-rate "$file" | paste - - | awk '{print $1 / $2}' | cut -d'.' -f1)"

	result="$(get_lyrics "$track_name" "$artist_name" "$album_name" "$duration")"

	unsynced_lyrics="$(jq -rc .plain_lyrics <<<"$result" 2>/dev/null)"
	synced_lyrics="$(jq -rc .synced_lyrics <<<"$result" 2>/dev/null)"

	patched=0
	if [[ "$unsynced_lyrics" != "null" ]] && [[ -n "$unsynced_lyrics" ]]; then
		patched=1
		echo "$unsynced_lyrics" >ul
		if [[ -z "$DRY_RUN" ]]; then
			metaflac --preserve-modtime --set-tag-from-file=UNSYNCEDLYRICS=ul "$file"
		else
			echo metaflac --preserve-modtime --set-tag-from-file=UNSYNCEDLYRICS=ul "$file"
		fi
	fi

	if [[ "$synced_lyrics" != "null" ]] && [[ -n "$synced_lyrics" ]]; then
		patched=1
		echo "$synced_lyrics" >sl
		if [[ -z "$DRY_RUN" ]]; then
			metaflac --preserve-modtime --set-tag-from-file=LYRICS=sl "$file"
		else
			echo metaflac --preserve-modtime --set-tag-from-file=LYRICS=sl "$file"
		fi
	fi

	total_patched=$((total_patched + patched))
done < <(find "$BASE_PATH" -iname '*.flac')

echo "analyzed: $total_analyzed"
echo "patched: $total_patched"
echo "fixed: $total_fixed"
echo "skipped: $total_skipped"
