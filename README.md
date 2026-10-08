# Fall Festival Roster — Flutter + SQLite

## Overview

This project is a Flutter mobile application that stores Fall Festival guest records locally using SQLite. The app supports adding, editing, cancelling edits, deleting, refreshing, and validating guest records.

## Technologies

- Flutter
- Dart
- SQLite
- sqflite
- path_provider
- path

## Database Schema

The application uses one SQLite table named `my_table`.

| Column | Type | Constraint |
|---|---|---|
| `_id` | INTEGER | PRIMARY KEY |
| `name` | TEXT | NOT NULL |
| `age` | INTEGER | NOT NULL |

The database helper initializes `MyDatabase.db` and provides insert, query, update, and delete operations.

## Validation

- Guest name cannot be blank or whitespace only.
- Age must be a whole number.
- Age must be between 0 and 130 inclusive.
- Invalid input is rejected before writing to SQLite.

## Manual Test Evidence

| Test | Action/Input | Expected | Observed | Result |
|---|---|---|---|---|
| T1 | Refresh empty roster | Count 0 and empty state | Count 0 and empty state displayed | PASS |
| T2 | Add River 21 and River 34 | Count 2 with distinct IDs | ID 1 = River 21, ID 2 = River 34 | PASS |
| T3 | Edit ID 2 to 99, cancel, then edit to 35 and save | Cancel keeps 34; save changes to 35 | ID 2 remained 34 after cancel and became 35 after save | PASS |
| T4 | Stop app, force stop, and relaunch | Same records survive | ID 1 and ID 2 data survived restart | PASS |
| T5 | Cancel deletion of ID 1, then confirm deletion | Cancel keeps record; confirmed delete removes it | ID 1 removed and count became 1 | PASS |
| T6 | Test invalid values and age boundaries | Invalid values rejected; 0 and 130 accepted | Invalid values rejected; boundary ages accepted; final count 3 | PASS |

## T4 Persistence Evidence

- `evidence/T4_before.png` — records before stopping the application.
- `evidence/T4_after.png` — records after force stopping and relaunching the application.

The records survived because they were stored in SQLite rather than only in temporary widget state.

## T6 Validation Evidence

- `evidence/T6_invalid.png` — validation feedback for an invalid age input.

## Analyzer Evidence

- `evidence/analysis_output.txt` contains the final `flutter analyze` output.
- Final result: `No issues found!`

# Graduate Reflection

## 1. The disappearing-data mystery

Before T4, I predicted that the saved River records would survive because they were written to SQLite instead of being stored only in widget memory. My records were ID 1 (River, 21) and ID 2 (River, 35), with a count of 2. I stopped the application, force-stopped it, and relaunched the same installation, and the same IDs, names, ages, and count were still present. If the roster had returned empty or the records had received different IDs, that would have disproved my claim that SQLite restored the data.

## 2. Two Rivers, one wrong edit

The two River records had the same name but different IDs, so the name alone was not a reliable identifier. I edited ID 2 from age 34 to 35, which showed that the update targeted the selected database ID. If the list were sorted differently, selecting a record by list position could target the wrong guest because the same position could represent a different database row after sorting.

## 3. My own usability walkthrough

The Add, Edit, Cancel, and Delete operations were easy to follow because the same form was reused for adding and editing. Cancelling the edit did not change the stored value, while saving the edit changed ID 2 from age 34 to 35. The T6 validation tests showed that invalid input did not increase the record count, while the valid boundary ages 0 and 130 were accepted.

## 4. Defend the storage boundary

The database schema uses `NOT NULL`, but this alone would still allow an empty string for a name or an invalid integer such as a negative age. I therefore enforce the name and age rules in the UI before writing to SQLite, which provides immediate feedback but means another code path could bypass those UI rules. If the `CREATE TABLE` statement were changed for an existing version-1 database without increasing the database version, the existing database would not automatically receive the new schema. A future migration would need to preserve the existing rows while changing the schema in a controlled versioned migration.

## Evidence Files

```text
evidence/
├── analysis_output.txt
├── T4_before.png
├── T4_after.png
└── T6_invalid.png