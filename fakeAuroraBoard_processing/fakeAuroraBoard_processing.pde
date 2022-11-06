import processing.serial.*;
import jssc.SerialPort;

Serial myPort;
String[] ports;

boolean portSelected = false;
boolean connecting = false;
boolean bootMessageReceived = false;

DataDecoder decoder = new DataDecoder();

void setup() {
  size(700, 780);
  drawCOMPorts();
  decoder.loadLEDPositions(sketchPath() + "/../positions.txt");
}

void drawCOMPorts() {
  background(255);
  fill(0);
  
  textSize(14);
  textAlign(LEFT);
  
  ports = Serial.list();
  for (int i = 0; i < ports.length; i++) {
    text(String.valueOf(i) + ":  " + ports[i], 30, i * 25 + 70);
  }
  text("r: Refresh port list", 30, ports.length * 25 + 70);
  
  textAlign(CENTER);
  textSize(21);
  text("Please select a serial port by pressing the corresponding number key:", width / 2, 30);
}

void openPort(String port) {
  try {
    myPort = new Serial(this, port, 115200);
    // DTR and RTS disabled is needed otherwise the ESP32 seems to stop when the serial port is closed.
    // It's either crashing or going into boot mode, dont really know and dont really care. This works so we're keeping it.
    myPort.port.setParams(115200, 8, SerialPort.STOPBITS_1, SerialPort.PARITY_NONE, false, false);
    myPort.clear();
  }
  catch (Exception e) {
    throw new RuntimeException(e);
  }
}

void keyPressed() {
  // If we are on the LED screen then only accept key presses on the 'q' kwy - in which case we close the port and go back to main COM port menu.
  if (portSelected) {
    if (key == 'q') {
      myPort.stop();
      portSelected = false;
      bootMessageReceived = false;
      drawCOMPorts();
    }
    return;
  }
  
  // 'R' key is refresh COM ports
  if (key == 'r') {
    drawCOMPorts();
    return;
  }
  
  int index = 0;
  try {
    index = Integer.parseInt(Character.toString(key));
  } catch (NumberFormatException nfe) {
    return;
  }
  
  if (index < ports.length) {
    background(255);
    text("Selected port " + String.valueOf(index) + ". Connecting...", width / 2, 150 + 25 * ports.length);
    openPort(ports[index]);
    portSelected = true;
    connecting = true;
  }
}

void drawEmptyBackground() {
  background(255, 255, 255);
  
  textSize(14);
  textAlign(LEFT);
  fill(0);
  text("Press 'q' to go back to COM port menu", 5, 13);
  
  fill(255, 255, 255);
  for (int x = 0; x < 17; x++) {
    for (int y = 0; y < 19; y++) {
      square(x * 40 + 15, y * 40 + 25, 25);
    }
  }
}

void draw() {
  if (!portSelected) return;
  
  if (connecting) {
    while (myPort.available() > 0) {
      if (bootMessageReceived) {
        decoder.setAPILevel(myPort.read());
        connecting = false;
        drawEmptyBackground();
        break;
      }
      // ESP32 will send a '4' just before it sends us the API level
      else if (myPort.read() == 4) {
        bootMessageReceived = true;
      }
    }
  }
  
  // If we have connected, then just wait until the decoder recevies all packets for a message, then draw the holds
  else {
    while (myPort.available() > 0) {
      decoder.newByteIn(myPort.read());
      if (decoder.allPacketsReceived) {
        drawEmptyBackground();
        for(Hold h : decoder.getCurrentPlacements()) {
          h.Draw();
        }
      }
    }
  }
}
