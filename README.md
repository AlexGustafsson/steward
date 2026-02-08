# Steward

Idea: Create an index of music.

Content: digest of audio data (FLAC-aware), file structure, metadata fields.

Use case: diff metadata between libraries, if two music libraries diverge, let
them coordinate.

TODO: Handle duplicates (audio hash not necessarily globally unique) when
indexing.

## Quick start

Scan through the library and write the entries to a compressed file.

```shell
./steward media/music | gzip > library.json.gz
```

Read an entry from the file.

```shell
gzip -d < library.json.gz | head -1
```

```jsonc
{
  "path": "music/Genesis-We_Can’t_Dance/04.I_Can’t_Dance.flac",
  "metadata": [
    "ACOUSTID_ID=26b5daef-5a1c-4ca4-ab10-8757e2da5d7e",
    "ALBUM=We Can’t Dance",
    // ...
    "TRACKNUMBER=4",
    "TRACKTOTAL=12"
  ],
  "digest": "sha256:8aa9d6eaeaa32803a484632c0b0a95a54f6bccf2873e382f913d4834f31833ff"
}
```

NOTE: The digest is of the audio frames inside of the FLAC file, not the file
itself. As such it is not affected by changing the metadata of the file,
changing its name or location. Only re-coding the audio should have an affect,
which makes it great for identifying differences in metadata.

## Name

Musicbrainz' excellent GUI tool is called Picard. The actor playing Picard is
Stewart and this tool (and to some extent Picard) is a _steward_ of FLAC
metadata.
