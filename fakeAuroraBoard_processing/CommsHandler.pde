import processing.serial.*;
import jssc.SerialPort;
import java.util.Arrays;

public enum BoardState {
  IDLE,
  BOOTING,
  CONNECTING,
  CONNECTED
}

public class CommsHandler {  
  private BoardState currentState = BoardState.IDLE;
  
  private final int BAUD_RATE = 115200;
  private Serial myPort;
  
  private String currentPort;
  private String[] ports;
  
  // We send pings to the board to give us the API level - this represents the last time this was done.
  private long timeOfLastAPILevelPing = 0;
  
  public CommsHandler() {
    refreshPorts();
  }
  
  public void refreshPorts() {
    ports = Serial.list();
  }
  
  public String[] getPorts() {
    return ports.clone();
  }
  
  public final BoardState getState() {
    return currentState;
  }
  
  // Opens serial port with the specified index - this index is from the ports[] array member variable.
  // Pass the main sketch object for the parent variable - e.g. 'this' from the main sketch file.
  public boolean openPort(PApplet parent, String port) {
    try {
      currentPort = port;
      myPort = new Serial(parent, port, 115200);
      // DTR and RTS disabled is needed otherwise the ESP32 seems to stop when the serial port is closed.
      // It's either crashing or going into boot mode, dont really know and dont really care. This works so we're keeping it.
      myPort.port.setParams(BAUD_RATE, 8, SerialPort.STOPBITS_1, SerialPort.PARITY_NONE, false, false);
      myPort.clear();
      
      currentState = BoardState.BOOTING;
      
      return true;
    }
    catch (Exception e) {
      return false;
    }
  }
  
  public void closePort() {
    myPort.stop();
    currentState = BoardState.IDLE;
  }
  
  // Call every draw loop. If the board is currently booting or connecting, this function will detect when that process is complete.
  // If the board has connected, this functoin returns the API level that should be used. Otherwise returns -1.
  public int checkForAPILevel() {
    while (myPort.available() > 0) {
      if (currentState == BoardState.CONNECTING) {
        currentState = BoardState.CONNECTED;
        
        int apiLevel = myPort.read();
        if (apiLevel < 1 || apiLevel > 9) // Make sure the API level is valid
          apiLevel = -1;
        return apiLevel;
      }
      // ESP32 will send a '4' just before it sends us the API level
      else if (myPort.read() == 4) {
        currentState = BoardState.CONNECTING;
      }
    }
    
    // If we still haven't received by this point then the board didn't boot so send out a ping every 1s.
    // It will know to send the API level once it receives a ping.
    if (millis() - timeOfLastAPILevelPing > 1000) {
      myPort.write(4);
      timeOfLastAPILevelPing = millis();
    }
    
    return -1;
  }
  
  // Checks if the serial port is still open.
  public boolean portOK() {
    boolean active = Arrays.asList(Serial.list()).contains(currentPort);
    if (!active)
      closePort();
    return active;
  }
  
  public int read() {
    if (currentState != BoardState.CONNECTED)
      return -1;
    else
      return myPort.read();
  }
  
  public int bytesAvailable() {
    return myPort.available();
  }
};
