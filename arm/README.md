# Arm Wearable STMCubeIDE Files

## I/O 
// TODO: talk more about how you convert raw readings to useful info  
### Inputs 
* EMG sensor: charge-up/starting the game  
* Joystick: horizontal movement on screen  
* Accelerometer: sense punching movement   
### Outputs
* Vibration motor: Haptic feedback when attacked by opponent  

## Communication
Communication between wearable nodes and the Main STM is handled wirelessly using XBee modules over UART.

The Main STM uses a round-robin polling scheme:
1. Main STM requests data from a wearable node
2. The wearable node responds with its latest state
3. Main STM stores the received data
4. Main STM moves to the next wearable node

The arm node transmits:
* Punch state
* Joystick direction
* EMG charge-up value  //uhh forgot if we changed this or not

The arm node receives:
* Vibration commands from the Main STM


