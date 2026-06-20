# Main STM STMCubeIDE Files

The Main STM serves as the central controller for the system. It coordinates communication between the wearable STM32 nodes, manages audio playback, and distributes feedback commands to the wearable devices.

## Peripherals
* Speaker: plays background music and sound effects
* SD Card: stores audio files
* FPGA: processes game logic 

## Communication
The Main STM serves as the communication hub for the system.

### Wearable Communication
Communication with the wearable STM32 nodes is performed wirelessly using XBee modules over UART.

Each wearable node is assigned a unique device address:
1. Player 1 Arm (000)
2. Player 1 Leg (001)
3. Player 2 Arm (010)
4. Player 2 Leg (011)

The Main STM polls the four wearable nodes in a round-robin sequence (in order above). Upon receiving a request from the Main STM, the addressed wearable node responds with its latest player state information.

After receiving data from all wearable nodes, the Main STM combines the player state information into a 3 byte information packet and forwards it to the FPGA.

### FPGA Communication
//should probs be added here unless somewhere else makes more sense

### Audio System
The Main STM manages all in-game audio playback. Background music is continuously streamed from the SD card and played through the speaker, while sound effects are triggered in response to game events received from the FPGA.

Examples include:
* Punch sound effects
* Impact sounds for successful hits
* Jump sound effects
* Power-up sound effect
* Round start and end audio cues

### Haptic Feedback
The Main STM receives game event information from the FPGA and sends vibration commands to the appropriate wearable node using its device address. This allows haptic feedback to be selectively triggered for the affected player.
