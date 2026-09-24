# Contributing to StrokeSentry

Thanks for your interest. This is a small, dependency-free SwiftUI app, so getting started is quick.

## Setup

1. Fork and clone the repo.
2. Open `StrokeSentry.xcodeproj` in Xcode 16 or later.
3. Set your own signing team on the `StrokeSentry` target.
4. Run on a physical iPhone. The simulator has no camera or microphone, so the tests cannot be exercised there.

## Making changes

- Keep changes focused. One fix or feature per pull request.
- Match the existing style: SwiftUI views under `Views/`, non-UI logic under `Managers/` or `Models/`.
- If you change a detection threshold or scoring formula, explain in the PR why the new value is better and how you checked it.
- Test on a real device before opening a PR, and say which device and iOS version you used.

## Reporting issues

Open a GitHub issue with the device, iOS version, which test was running, and what you expected versus what happened. Screenshots or screen recordings help a lot for detection problems.

## A note on scope

StrokeSentry is an educational screening tool, not a medical device. Please do not open PRs that present results as a diagnosis, remove the disclaimers, or add claims of clinical accuracy that the code does not support. The [Known limitations](README.md#known-limitations) section of the README lists areas where help is especially welcome.
