The idea is to use rclone to get all backends for free, but for now only build
for b2 as that's what's used.

Next, the idea is to have two file system implementations:

- IndexFS - uses an index from the local file system with digests, sizes and
  file paths - all information. Used only for uploading data as it can be used
  to effectively copy files with rclone to the remote
- DiffFS - essentially a local fs that will handle creating files based on
  metadata. So first store files to a temporary directory and then moving them
  to the right location based on file metadata and naming scheme. NOTE: This
  also has to diff against the index - if an entry already exists it can be
  ignored (based on audio hash!)!
