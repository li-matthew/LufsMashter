# LufsMashter Audio Unit
Free AU true peak limiting and loudness normalizing plugin for macOS. When run, it uses a host app to play an audio file specified in 
`/LufsMashter/Common/Audio/SimplePlayEngine.swift`, but it also serves as an audio unit that can be integrated into DAWs for audio processing.

## Features
### True Peak Limiter
* Optional pre limiter soft clipping at +3db from the threshold
* Oversampling at 2x/4x/8x/16x
* True peak limiting with attack and release
* Optional post limter hard clipper at the threshold

### Loudness Normalizer
* Calculates integrated LUFS(ITU-R BS.1770-5) of a recorded segment of audio 
* Applies linear gain reduction to incoming audio to match the integrated lufs to a targeted LUFS value 

* Rolling chart of true peak and LUFS measurements with a toggle to switch between views
* Measurement readouts

## Prerequisites
* XCode (>14 recommended)
* macOS (>Monterey)
* (Optional) DAW (supports AUv3 extensions)

## Build


There are 5 types of Audio Unit Extensions, each type is represented by a four character code.

|Name|Four Character Code|
|---|---|
|Effect|aufx|
|Music Effect|aumf|
|MIDI Processor|aumi|
|Instrument|aumu|
|Generator|augn|


## Languages
This template uses Swift/SwiftUI for business logic and user interface and C++ (via Swift/C++ Interoperability) for real-time constrained areas.

## Project Layout
This template is designed to make Audio Unit development as easy as possible. In most cases you should only need to edit files in the top level groups; `Parameters`, `DSP` and `UI` groups.

* /Common - Contains common code split by functionality which should rarely need to be modified. 
	* `Audio Unit/LufsMashterExtensionAudioUnit.swift` - A subclass of AUAudioUnit, this is the actual Audio Unit implementation. You may in advanced cases need to change this file to add additional functionality from AUAudioUnit.  
* /Parameters
	* `LufsMashterExtensionParameterAddresses.h` - A pure `C` enum containing parameter addresses used by Swift and C++ to reference parameters.
	
	* `Parameters.swift` - Contains a ParameterTreeSpec object made up of ParameterGroupSpec's and ParameterSpec's which allow you describe your plug-in's parameters and the layout of those parameters.

* /DSP
	* `LufsMashterExtensionDSPKernel.hpp` - A pure C++ class to handle the real-time aspects of the Audio Unit Extension. DSP and processing should be done here. Note: Be aware of the constraints of real-time audio processing. 
* /UI
	* `LufsMashterExtensionMainView.swift` - SwiftUI based main view, add your SwiftUI views and controls here.

## Adding a parameter
1. Add a new parameter address to the `LufsMashterExtensionParameterAddress` enum in `LufsMashterExtensionParameterAddresses.h` 


Example:

```c
typedef NS_ENUM(AUParameterAddress, LufsMashterExtensionParameterAddress) {
	sendNote = 0,
	....
	attack
```

2. Create a new `ParameterSpec` in `Parameters.swift` using the enum value (created in step 1) as the address.

Example:

```swift
ParameterGroupSpec(identifier: "global", name: "Global") {
	....
	ParameterSpec(
		address: .attack,
		identifier: "attack",
		name: "Attack",
		units: .milliseconds,
		valueRange: 0.0...1000.0,
		defaultValue: 100.0
	)
	...
```
Note: the identifier will be used to interact with this parameter from SwiftUI.

3. In order to manipulate the DSP side of the Audio Unit we must handle changes to our new parameter in `LufsMashterExtensionDSPKernel.hpp`. In the `setParameter` and `getParameter` methods add a case for the new parameter address.

Example:

```cpp
	void setParameter(AUParameterAddress address, AUValue value) {
		switch (address) {
			....
			case LufsMashterExtensionExtensionParameterAddress:: attack:
				mAttack = value;
				break;			
			...
	}
	
	AUValue getParameter(AUParameterAddress address) {
		switch (address) {
			....
			case LufsMashterExtensionExtensionParameterAddress::attack:
				return (AUValue) mAttack;
			...
	}
	
	// You can now apply attack your DSP algorithm using `mAttack` in the `process` call. 
```

4. For Audio Units that present a user interface, you should expose or access the new parameter in your SwiftUI view. The parameter can be accessed using its identifier (defined in step 2). It is accessed using dot notation as follows parameterTree.<ParameterGroupSpec Identifier>.<ParameterGroupSpec Identifier>.<ParameterSpec Identifier>

Example

```Swift
// Access the attack parameters value from SwiftUI
parameterTree.global.attack.value

// Set the attack parameters value from SwiftUI
parameterTree.global.attack.value = 0.5

// Bind the parameter to a slider
struct EqualizerExtensionMainView: View {
	...	
	var body: some View {
		ParameterSlider(param: parameterTree.global.attack)
	}
	...
}

/*
Note: the parameterTree.<parameter_name> must match the structure and identifier of the parameter defined in `Parameters.swift`.
*/
```

## Catalyst / iPhone and iPad apps on Mac with Apple silicon
To build this template in a Catalyst or iPhone/iPad App on Mac with Apple silicon, perform the following steps:  

1. Select your Xcode project in the left hand side file browser
2. Select your app target under the 'TARGETS' menu
3. Under 'Deployment Info' select 'Mac Catalyst' (Note: Skip this step for iPhone and iPad apps on Mac with Apple silicon)
4. Select the 'General' tab in the top menu bar
5. Under 'Frameworks, Libraries, and Embedded Content' click the button next to the  iOS filter
6. In the pop-up menu select 'Allow any platforms'

## More Information
[Apple Audio Developer Documentation](https://developer.apple.com/audio/)
