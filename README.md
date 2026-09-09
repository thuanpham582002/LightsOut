<div align="center">
<a href="https://github.com/AlonX2/LightsOut/releases/"><img src="https://github.com/user-attachments/assets/2007db73-5485-4296-9205-e9626ff3ac81" width="128" height="165" alt="LightsOut" align="center"/></a>

<h2>LightsOut</h2>
<p><b>Forever free</b> menubar utility to disable any monitor with a simple button press - No more cable fidgeting or using bloated apps!</p>
<a href="https://github.com/AlonX2/LightsOut/releases/download/v1.0.5/LightsOut.dmg"><img src="https://user-images.githubusercontent.com/37590873/219133640-8b7a0179-20a7-4e02-8887-fbbd2eaad64b.png" width="180" alt="Download for macOS"/></a><br/>
<sub><b>The <a href="https://github.com/AlonX2/LightsOut/releases/">latest app version</a> requires macOS Ventura, Sonoma or Sequoia.<br>
</div>

## Rebuild and redeploy with the same signature

Run `bash Scripts/build-and-install.sh` from the repository, or pass an absolute
derived-data directory as the first argument to reuse an existing build cache.
The script runs safety tests, builds Release, finds the installed app's exact
certificate in the signing keychain, preserves its entitlements, and verifies
the certificate and designated requirement before replacing `/Applications/LightsOut.app`.
It requires the matching private key and refuses an entitlements mismatch.
The current app quits gracefully; a timestamped backup is retained next to it.
Installation/launch failures trigger rollback. No force-kill is used.

## Remembered display configuration

Normal disable remembers the target display UUID, true-disconnect mode and the UUIDs of the
visible supporting monitors. Automatic recovery changes the observed state only.
When a remembered supporting monitor returns awake and usable, LightsOut waits
three stable seconds before reapplying the saved off state through the normal
last-visible-display checks. A different monitor reusing the same numeric ID does
not qualify. Restore is paused during recovery, sleep and observed locked/inactive
sessions. A failed restore is not repeated until the display topology changes or
the user makes a new manual choice.

Explicit Enable removes that monitor's off preference. Reset, Recover and the
emergency hotkey clear all off preferences, so a manual rescue cannot immediately
be undone. Normal quit preserves preferences for the next launch. Preferences are
stored separately from the recovery journal; deployment migrates older saved off
states before quitting the old app.

The built-in panel now uses true disconnect. Recovery intentionally uses two
separate WindowServer transactions: enable an offline panel first, then unmirror
only on a later inventory pass if needed. Combining both changes caused macOS
error 1001 on this machine. Shift-disable remains the explicit mirror-blackout
mode and is shown as `Dimmed`, not as the normal disabled state.

## Display recovery safety

LightsOut now refuses to hide the last awake, visible display. Hiding the built-in
panel uses mirroring plus gamma blackout instead of removing the panel from
WindowServer's inventory. Enabling any hidden display restores all displays,
because ColorSync gamma restoration is global.

While LightsOut is running, display removal notifications and a one-second
watchdog restore hidden displays when a supporting monitor disappears or no
visible monitor remains. Sleep, wake, normal quit, and startup with unfinished
recovery state also trigger restoration. Gamma retry timers are cancelled before
restoration; a failed configuration retains its display ID for subsequent retries.
Each recovery attempt is bounded to eight seconds. A failed device shows a Retry
button and the macOS error instead of an indefinite Pending state. Repeated
notifications do not extend the deadline. Hiding is blocked only during that
attempt; the last-visible-display guard remains enforced afterward. If no usable
display remains, recovery is retried at a slower cadence.

The display list is reconciled with the online hardware inventory on every
watchdog pass. A healthy live display overrides stale Pending/Disabled state;
names and primary status are refreshed, and UUID checks prevent transferring a
blackout to a different monitor that reuses the numeric display ID. Ghost external
Pending rows are removed; evidence for app-disabled devices and the built-in panel
remains available for recovery.

Emergency recovery while the app is running: **Control + Option + Command + R**.
The shortcut requires successful system registration and can conflict with another
app. It is not a supported recovery mechanism at the lock/login screen. LightsOut
instead attempts recovery on session changes and lock/unlock notifications; the
latter are undocumented macOS events and their delivery is best-effort. Topology
monitoring and the watchdog remain independent of these events. An alternative
is `open 'lightsout://recover'` from Terminal or SSH in the logged-in GUI session. Neither
automatic recovery path restarts WindowServer or logs out the user.

Recovery depends on the app/main run loop and macOS display services responding;
it cannot guarantee recovery from an app hang, WindowServer/driver failure, or a
closed laptop lid. After an app crash, relaunch LightsOut to consume the saved
recovery state. Physical unplug/replug validation is still required on the target
Mac and dock before relying on this in daily use.

### Validation

Run `bash Scripts/test-safety.sh` for exhaustive five-display topology policy
cases, cancellation of delayed gamma writes, loss of the last alternate display
during a gamma retry, and recovery-state persistence/write-failure checks. These
tests inject gamma writes and do not change the machine's displays.

Hardware acceptance checks: hide the built-in panel, unplug the only external
monitor; rapidly disconnect/reconnect a dock; unplug during the first five seconds
of blackout; sleep/wake; restore with the emergency shortcut while another app is
focused; quit/relaunch with a hidden display. Confirm the built-in panel becomes
usable, stays usable beyond five seconds, and recovery never re-hides it.
Also lock the Mac while the built-in panel is hidden, unplug the external monitor,
and check that the built-in login screen becomes visible without relying on a hotkey.
<hr>
<div align="center">
  <h4>Well they do say a picture is worth a thousand words, and in this case leaves little room for more storytelling:</h4>
  <img src="https://github.com/user-attachments/assets/97e0f575-d479-4cd9-80ac-345f952cabeb" alt="Very cool screenshot" align="center"/>
</div>
