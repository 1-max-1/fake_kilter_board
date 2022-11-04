import processing.serial.*;
import jssc.SerialPort;

Serial myPort;
String[] ports;

boolean portSelected = false;
boolean connecting = false;
boolean bootMessageReceived = false;

DataDecoder decoder = new DataDecoder();

void setup() {
  size(760, 780);
  background(255);
  fill(0);
  
  textSize(14);
  ports = Serial.list();
  for (int i = 0; i < ports.length; i++) {
    text(String.valueOf(i) + ":  " + ports[i], 30, i * 25 + 70);
  }
  
  textAlign(CENTER);
  textSize(21);
  text("Please select a serial port by pressing the corresponding number key:", width / 2, 30);
  
  decoder.loadLEDPositions(sketchPath() + "/../positions.txt");
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
  if (portSelected) return;
  
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
  fill(255, 255, 255);
  for (int x = 0; x < 17; x++) {
    for (int y = 0; y < 19; y++) {
      square(x * 40 + 30, 780 - (y * 40) - 40, 25);
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
      else if (myPort.read() == 4) {
        bootMessageReceived = true;
      }
    }
  }
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
