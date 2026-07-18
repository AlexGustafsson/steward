#!/usr/bin/env bash

file="$1"

selected="$(jq -rc '.Metadata | map(select(startswith("ALBUM=") or startswith("ALBUMARTIST=")) | sub("^[^=]*="; ""))' <"$file" | sort -u | fzf --multi | jq -rcs .)"

jq -rc --argjson pairs "$selected" '. as $obj
| select(
    any(
      $pairs[];
      . as $pair
      | any($obj.Metadata[]; . == ("ALBUM=" + $pair[0]))
      and any($obj.Metadata[]; . == ("ALBUMARTIST=" + $pair[1]))
    )
  )' <"$file"
