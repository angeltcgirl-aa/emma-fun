# Photo & video cleanup plan

Goal: 25+ years of photos and videos cleaned up, deduped, searchable in Google Photos,
with a master copy on Angel's own drive.

## Decisions
- **Search home:** Google Photos (people, places, descriptions, albums).
- **Master archive:** external drive, folders like `2011/2011-03-skating-regionals/`. This is the source of truth; Google Photos is not a backup.
- **Madi's skating videos:** YouTube (her preference, she doesn't want her stuff in Angel's Google Photos/Drive). Originals still backed up on the external drive.
- **Storage:** Angel has a Google One plan with 2 TB, so there's plenty of room to upload at **Original quality** (not Storage saver). Set it before any upload.
- Google Photos has no true tags: use **descriptions**, dates, GPS and people labels. Write them into the files with exiftool before upload. Albums are built by hand at the end.

## Status
- [x] External drive bought and connected
- [x] Takeout export started: Google Drive, Google Photos, YouTube
- [ ] Verify YouTube export includes the actual video files (Madi's old skating videos only live on YouTube)

## Phases
1. Land the Takeout exports on the external drive; verify they're complete.
2. Merge Drive backup copies, remove duplicates (exact + near-duplicate).
3. Catalog (spreadsheet: date, location, album, size, duplicate flag) and flag junk: screenshots, blurry shots.
4. Delete junk in Google Photos.
5. Bulk-fix dates, GPS, descriptions with exiftool; upload.
6. Rip Madi's skating DVDs (HandBrake/ffmpeg to MP4, named by date + event); organize her YouTube channel.
7. Scan pre-digital prints (600 dpi, one folder per batch), stamp metadata per batch.
8. Build albums last.
9. Second backup drive, kept off-site.

## Fill in offline (airplane homework)
- Folder/naming convention: `YYYY-MM-event` OK?
- People list with nicknames (who to label):
- Places that matter (home, rinks, trips):
- Rough year ranges for the scanned prints:
- What are the discs: DVD video, or data CDs?
