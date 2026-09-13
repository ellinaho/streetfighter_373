# Leg Wearable STMCubeIDE Files

// TODO: brief summary what this does  

## I/O
### Inputs
* Accelerometer: used to sense jumping motion

### Communication
Communication between wearable nodes and the Main STM is handled wirelessly using XBee modules over UART.

The Main STM uses a round-robin polling scheme:
1. Main STM requests data from a wearable node
2. The wearable node responds with its latest state
3. Main STM stores the received data
4. Main STM moves to the next wearable node

The leg node transmits:
* Jump state
