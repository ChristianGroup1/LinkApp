# Feature Structure

The production MVP will move screen-by-screen into this feature layout:

- `auth`: login, registration, profile bootstrap.
- `church`: church context and settings.
- `meetings`: grouped-by-class and direct meeting CRUD.
- `members`: members scoped to a class or direct meeting.
- `attendance`: weekly sessions and fast attendance marking.
- `reports`: monthly, class, meeting, and member statistics.
- `follow_up`: consecutive absence workflows and follow-up notes.

The existing app still uses the legacy screens while the migration happens.
