# Steward

Steward is a WIP all-in-one tool to index, diff, backup and replicate large FLAC
libraries. Though largely meant for my personal use, you might find use of the
tool.

It effortlessly allows you to backup and restore your music to S3-compatible
storage, with audio content-adressable storage so that changes to metadata
doesn't require you to upload or download the large files anew.

Apart from running Steward as a CLI on host or inside of a Docker container, a
native macOS UI allows you to use Steward for simpler use cases as well.

## Quick start

Scan through the library and write the entries to a compressed file.

```shell
./steward index media/music | gzip > library.json.gz
```

Read an entry from the file.

```shell
gzip -d < library.json.gz | head -1
```

```jsonc
{
  "Name": "media/music/Genesis/We Can't dance/Track 01.flac",
  "ModTime": "2026-01-06T19:20:34.989036+01:00",
  "Size": 30915750,
  "Metadata": [
    "ALBUM=We Can't Dance",
    "ARTIST=Genesis",
    "CDDB=aa10c90c",
    "DATE=1991",
    "GENRE=pop",
    "GENRE=progressive rock",
    "TITLE=Jesus He Knows Me",
    "TRACKNUMBER=02",
    "TRACKTOTAL=12"
  ],
  "AudioDigest": "md5:e79c8464b88e88ed2bcc6584fa5bcd43",
  "PictureDigest": "md5:d41d8cd98f00b204e9800998ecf8427e"
}
```

NOTE: The digest is of the audio frames inside of the FLAC file, not the file
itself. As such it is not affected by changing the metadata of the file,
changing its name or location. Only re-coding the audio should have an affect,
which makes it great for identifying differences in metadata.

## Name

Musicbrainz' excellent GUI tool to work with annotating music files is called
Picard. The actor playing Picard is Stewart and this tool (and to some extent
Picard) is a _steward_ of FLAC metadata.
