# Local Storage Lab — Activity 08 and Activity 09

**Course:** Mobile Application Development  
**Assignment:** In-Class Activity 09 — Local Storage: Connect the Pieces  
**Student:** Nallapaneni Mouni Sri  
**Pathway:** Graduate  
**Platform:** Flutter + SQLite

## 1. Project Overview

This project extends the Flutter and SQLite application from Activity 08. Activity 08 stored guest records in a single table. Activity 09 adds a card catalogue with folders and cards, using a relational database structure.

The application supports:

- Creating folders and displaying the number of cards in each folder.
- Opening a folder to view its cards.
- Adding and editing cards.
- Deleting cards and folders with confirmation.
- Rejecting blank folder names, blank card titles, and duplicate folder names.
- Preserving data across an app force-stop and relaunch.
- Enforcing folder–card relationships through SQLite foreign keys.
- Displaying a suit-symbol fallback when a card has no image reference.

## 2. Technologies Used

- Flutter and Dart
- SQLite through `sqflite`
- `path` for database path handling
- `path_provider` for the application documents directory
- Android emulator for application testing

## 3. Activity 08 — Original Guest Table

The original database filename is `MyDatabase.db`. The original table is `my_table`, with the following columns:

| Column | Type | Purpose |
|---|---|---|
| `_id` | INTEGER PRIMARY KEY | Identifies each guest record |
| `name` | TEXT NOT NULL | Guest name |
| `age` | INTEGER NOT NULL | Guest age |

### Historical Activity 08 Evidence

The saved Activity 08 screenshot shows the following guest records in the original application before they were deleted:

| ID | Name | Age |
|---:|---|---:|
| 2 | river | 35 |
| 3 | Acron | 0 |
| 4 | oak | 130 |

The screenshot is retained as historical evidence of the original guest roster and its displayed IDs and values. These records were present in the Activity 08 application before the Activity 09 migration work.

The current database diagnostic shows that `my_table` is empty. Therefore, the screenshot establishes the earlier records, while the current diagnostic describes the present database state. The screenshot alone does not establish that the original rows survived the migration.

## 4. Activity 09 — Database Schema and Migration

The database version was increased from **1 to 2**, retaining the database filename `MyDatabase.db`.

The implementation uses `onUpgrade` to create the new catalogue tables for an existing version-1 database. The original `my_table` definition is also included in `onCreate` so a fresh installation creates the original table and the catalogue tables.

### `folders` table

| Column | Type | Constraint |
|---|---|---|
| `id` | INTEGER | Primary key, autoincrement |
| `name` | TEXT | NOT NULL, UNIQUE |
| `created_at` | TEXT | NOT NULL |

### `cards` table

| Column | Type | Constraint |
|---|---|---|
| `id` | INTEGER | Primary key, autoincrement |
| `title` | TEXT | NOT NULL |
| `suit` | TEXT | NOT NULL |
| `notes` | TEXT | NOT NULL, default empty string |
| `image_ref` | TEXT | Nullable |
| `folder_id` | INTEGER | NOT NULL, foreign key to `folders(id)` |

The relationship uses `ON DELETE CASCADE`. When a folder is deleted, its associated cards should also be deleted. Foreign-key enforcement is enabled through `PRAGMA foreign_keys = ON` in `onConfigure`.

The index `idx_cards_folder_id` is created on `cards(folder_id)` to support queries that retrieve cards by folder.

## 5. Models and Database Operations

The application uses typed models:

- `Folder` represents a folder and includes its ID, name, creation timestamp, and displayed card count.
- `CardRecord` represents a card and includes its ID, title, suit, notes, optional image reference, and folder ID.

Database operations are implemented in `DatabaseHelper`, keeping SQL operations outside the UI widgets.

The helper supports:

- Creating and retrieving folders.
- Retrieving folder card counts.
- Creating, retrieving, updating, and deleting cards.
- Deleting folders.
- Validating folder names and card titles.
- Restricting suits to Hearts, Diamonds, Clubs, and Spades.

Card records are identified by their database IDs rather than their titles or positions in the displayed list.

## 6. Testing and Observed Results

The following results reflect the tests performed during development. Screenshots should be saved in `evidence/activity09/` using the corresponding filenames.

| Test | Procedure | Observed result | Status |
|---|---|---|---|
| T1 — Migration and original data | Review the historical Activity 08 screenshot and inspect the current database diagnostics. | The screenshot shows the original three guest records. The current `my_table` diagnostic is empty, so preservation of those rows through migration cannot be confirmed from the current database. | Partial — limitation documented |
| T2 — Folder and card creation | Create Atlas and Harbor; add cards to the folders. | Harbor contains Signal, card ID 3, with suit Diamonds. Atlas was used for Compass card tests. Additional test records were also created during development. | Tested |
| T3 — Edit and cancel | Edit card ID 4 and save; edit card ID 2 and cancel. | ID 4 displayed `Compass revised` with notes `Updated for Activity 09 test`. The cancelled edit to ID 2 did not save its attempted changes. | Pass |
| T4 — Persistence | Force-stop and relaunch the application without clearing its data. | The user observed that saved card values persisted after relaunch. Attach a screenshot captured after relaunch as `T4_after.png`. | Tested |
| T5 — Delete and cascade | Cancel and confirm card deletion; cancel and confirm folder deletion. | Cancellation left data unchanged. Confirmed deletion of Atlas removed its remaining cards. Harbor and its Signal card remained, with Harbor showing a count of 1. | Pass |
| T6 — Validation and image fallback | Try a blank folder name, a blank card title, and a duplicate folder name. Inspect Signal's image reference and fallback. | Invalid inputs were rejected with visible feedback. Duplicate Harbor was rejected. Signal's `image_ref` was `NULL`, and its suit-symbol fallback was visible. | Tested |

### T1 limitation

The historical screenshot is evidence of the original Activity 08 records, but it is not a post-migration database export. Because the current `my_table` diagnostic is empty, T1 is marked **Partial** rather than claiming that data preservation was verified. Any recovery or retest of the original database should follow the instructor's guidance.

## 7. Database Diagnostics

The diagnostic output from the current application reported:

```text
Database version: [{user_version: 2}]
Foreign keys enabled: [{foreign_keys: 1}]
Tables: [{name: android_metadata}, {name: cards}, {name: folders}, {name: my_table}, {name: sqlite_sequence}]
Cards foreign keys: [{id: 0, seq: 0, table: folders, from: folder_id, to: id, on_update: NO ACTION, on_delete: CASCADE, match: NONE}]
Card indexes: [{seq: 0, name: idx_cards_folder_id, unique: 0, origin: c, partial: 0}]
Original Activity 08 rows: []
All current cards: [{id: 3, title: signal, suit: Diamonds, notes: , image_ref: null, folder_id: 2}]
Signal image reference: [{id: 3, title: signal, suit: Diamonds, image_ref: null, folder_id: 2}]
```

These diagnostics confirm the current database version, enabled foreign keys, the catalogue tables, the folder relationship, the index, and Signal's null image reference. They also show that the original guest table is currently empty.

## 8. Flutter Analysis

Command executed from the project root:

```powershell
flutter analyze
```

Observed output:

```text
Analyzing local_storage_lab...
No issues found! (ran in 4.4s)
```

The Flutter analyzer completed successfully at the time this output was recorded.

## 9. Evidence Files

Keep Activity 08 evidence separate from Activity 09 evidence.

Expected Activity 09 evidence structure:

```text
evidence/
├── activity08/
│   └── [existing Activity 08 evidence]
└── activity09/
    ├── T1_before.png
    ├── T2_cards.png
    ├── T3_edit.png
    ├── T4_after.png
    ├── T5_folder_delete.png
    ├── T5_harbor_signal.png
    ├── T6_blank_folder.png
    ├── T6_blank_title.png
    └── analysis_output.txt
```

The files listed above were present in the project evidence folder when this README was updated. The Activity 08 screenshots are retained separately under `evidence/activity08/`.

`T1_before.png` should contain the historical Activity 08 screenshot showing river, Acron, and oak. `T4_after.png` should be captured after the force-stop and relaunch. `analysis_output.txt` should contain the actual database diagnostics and Flutter analyzer output.

## 10. Graduate Reflection

### Prompt 1 — Failure Reconstruction

The original guest records are visible in the historical Activity 08 screenshot, but the current database diagnostic returns an empty result for `my_table`. This means the current state cannot independently establish whether the original rows survived the migration. The appropriate response is to document the evidence accurately and seek an instructor-approved recovery or retest path rather than recreate records and describe them as preserved.

### Prompt 2 — Delete Policy Trade-Off

The catalogue uses `ON DELETE CASCADE` because cards belong to folders and should not remain attached to a folder that no longer exists. Foreign-key enforcement must be enabled on the database connection for this behavior to work. The folder-deletion confirmation provides an opportunity to warn the user that the associated cards will also be deleted. For data that must be retained, a soft-delete or reassignment strategy would be safer than cascading deletion.

### Prompt 3 — Image Forensics

The `image_ref` column is nullable. Signal has a `NULL` image reference, and the application displays a suit-symbol fallback rather than requiring an image. A reference is not the image itself: a file may be moved or deleted, an asset must be packaged with the application, and a remote URL may fail when offline. A robust implementation should validate the reference and provide a fallback whenever the image cannot be loaded.

### Prompt 4 — Version 3 Migration Design

A future version 3 could add an `is_favorite` integer column with a default value of `0` and a nullable `review_date` text column. The database version would increase to 3, and the migration should run only when `oldVersion < 3`, preserving existing folders, cards, and the original guest table.

The migration should be performed transactionally so a failure does not leave a partially upgraded schema. Existing cards should receive the defined default favorite value, while `review_date` should remain `NULL` until a review date is supplied. Validation should include a version-2 upgrade with existing records, a fresh installation, preservation of IDs and values, the new defaults, nullable review dates, foreign-key behavior, and a simulated migration failure. The test should verify that a failed upgrade rolls back cleanly and can be retried safely.

## 11. Submission Checklist

Update each checkbox only after verifying that the item is complete.

- [x] `README.md` updated for Activity 09.
- [x] Activity 08 evidence retained separately.
- [x] `flutter analyze` completed successfully — no issues found.
- [x] Required Activity 09 screenshots saved with the correct filenames.
- [x] `analysis_output.txt` contains database diagnostics and analyzer output.
- [x] Graduate Critical Thinking document drafted/reviewed and student ID entered; verify the final filename before upload.
- [x] `flutter build apk --release` completed successfully.
- [x] Release APK installed on the Pixel 10 emulator; persistence and card/folder deletion were smoke-tested. The title-edit check was not conclusively verified.
- [ ] `github_link.txt` created and checked for the correct repository URL.
- [ ] All three required files uploaded to iCollege and verified.

## 12. Final Deliverables

The required iCollege uploads are separate files:

1. `github_link.txt` — contains the URL of the student's GitHub repository.
2. `Activity09_Nallapaneni_MouniSri.apk` — release APK built successfully and smoke-tested on the Pixel 10 emulator. Rename it only if your instructor requires a different exact filename.
3. `Nallapaneni_MouniSri_CriticalThinking.docx` — Graduate reflection document; verify that the final file exists under this exact filename before uploading.

Before submission, create `github_link.txt` containing `https://github.com/MouniSri039/Activity09-Local-Storage`, verify the Critical Thinking document filename, and upload all three files separately to iCollege. Do not mark a test or deliverable complete unless it has been performed and verified.
