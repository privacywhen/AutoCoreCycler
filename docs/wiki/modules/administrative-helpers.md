# Module: Administrative helpers

## `add-eventlog-source.ps1`

[`helpers/add-eventlog-source.ps1`](../../../helpers/add-eventlog-source.ps1) creates the `CoreCycler` Application Event Log source. This requires elevation, so it is separated from the main process. It can optionally add an Event Viewer Custom View that filters this source.

## `automode-startup-script.ps1`

[`helpers/automode-startup-script.ps1`](../../../helpers/automode-startup-script.ps1) runs through the `CoreCycler AutoMode Startup Task` after an unexpected exit. It checks elevation, requires `.automode` or `.automode-bak`, validates fields and age, waits if configured, and restarts `Run CoreCycler.bat` with the stored core. It removes the task when recoverable state is absent.

## Discovery boundary

These helpers are recovery transport and Windows integration, not discovery evidence policy. Their current state schema has no candidate/stage identity or application-verification record. Later discovery phases must preserve their validated fallback behavior while extending the state contract carefully.
