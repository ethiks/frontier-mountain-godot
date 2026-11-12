# Unified market recovery — 2026-11-12

## Saved state inspected

Started from `main` at `ea2b185a5aceb13af4adf48ecbddbd70a38d30e4`.
The failed conversation had already saved the shared Sell Timber / Contracts /
Shop / Supplies sprite-based frame, hidden permanent logo and Camp/Market/Gear
shortcuts, floating top-right utility controls, five-second notification fade,
and world distributor width reduced from 408 to 285.6 (70% of its former size).
The last two commits also repaired sprite borders and detail placement.

## Remaining defects fixed

Category captions were refreshed per page, but desktop and mobile click
callbacks still captured the original equipment category keys. RAW LOGS, for
example, selected `tools` and produced an empty list. Buttons now resolve their
current page's category key when pressed. Equipment categories still work when
returning to Shop. Empty categories also refresh quantity-control visibility
and disabled states instead of retaining controls from another page.

## Verification

- Imported the project with official Godot 4.4.1 (the build script's version).
- Restored missing approved world crops locally from the saved
  `frontier-mountain-v062a-source-and-assets.zip` because the asset-host request
  stalled. No new artwork was introduced.
- Reproduced the defect against the starting commit: the new RAW LOGS button
  regression fails with exit code 1. The repaired code passes it.
- Fresh isolated save directories: forestry 40, progression 33, distributor 38,
  equipment shop 29, unified UI 40 passing assertions; all suites exit 0.
- Unified coverage includes both desktop and mobile category-button signals,
  empty contracts, tab switching, controller navigation, sale confirmation and
  quantities, contract acceptance, 844x390 layout, hidden shortcuts/logo,
  floating utility buttons, notification expiry, and exact market width.
- Release Web export completed successfully with official 4.4.1 templates;
  no script errors in the export log. `git diff --check` passes.

## Limits

The tests still emit shutdown resource/ObjectDB warnings; forestry also emits
a dummy-renderer texture warning, and progression intentionally parses a corrupt
save in its recovery test. These are not assertion failures and this change does
not resolve them. Similar shutdown warnings were present before this fix.

Fresh visual playtesting could not be completed: the native desktop could not
focus the Godot import dialog for text entry, and the cloud browser could not
connect to the local web server. Existing repository screenshots predate this
fix and are not presented as new verification. No physical phone or controller
was tested. The release build has not been deployed by this recovery task.

The fix is isolated to the market scripts and regression test; to undo it,
revert its commit. Save schemas and gameplay balance are unchanged.
