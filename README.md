# RAM Pressure Monitor for macOS

<b>I don't have the Apple Developer Program, so when you open the program it says "Apple was unable to verify... is free of malware that could harm your Mac or compromise your privacy".</b>

## Features

- **Menu Bar Status**: Displays the current RAM pressure status in the macOS menu bar.
- **Memory Pressure Levels**: Shows memory pressure levels: `normal`, `caution`, or `severe`.
- **Exit Option**: Allows the user to quit the app from the menu bar.

## Requirements

- macOS 10.15 or later.

## Installation
- Download the latest release
- Mount the DMG
- Drag to applications
- Launch the app

## How It Works
- The app uses Timer to update the RAM status every 7 seconds.
- It queries the system for memory pressure status using the sysctlbyname("kern.memorystatus_vm_pressure_level") function.
Example:<br/>
![Screenshot 1](screenshot%201.png) <br/>
![Screenshot 2](screenshot%202.png)

<b>- Image changes based on RAM memory status </b>

## Memory Pressure Levels
- Normal: The system has enough free memory.
- Caution: The system is starting to use more memory and may need attention.
- Severe: The system is under heavy memory pressure, and performance may be impacted.

## Usage
- When the app is running, you'll see the RAM pressure indicator in the macOS menu bar.
- The label will update every 7 seconds to show the current pressure level.
- To quit the app, click on the menu bar icon and select Exit or press `CMD + Q`;

