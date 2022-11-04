class DataDecoder { 
  private int currentPacketLength = -1;
  private ArrayList<Integer> currentPacket = new ArrayList<Integer>();
  private ArrayList<Hold> currentPlacements = new ArrayList<Hold>();
  private boolean allPacketsReceived = false;
  
  private int API_LEVEL = 2;
  private HashMap<Integer, int[]> positions = new HashMap<Integer, int[]>();
  
  public void loadLEDPositions(String positionsFile) {
    for(String line : loadStrings(positionsFile)) {
      String[] data = line.split(",");
      positions.put(Integer.valueOf(data[2]), new int[] {Integer.parseInt(data[0]), Integer.parseInt(data[1])});
    }
  }
  
  // TODO: make this better, instead of exiting return false so the user knows
  public void setAPILevel(int apiLevel) {
    println("API Level: " + apiLevel);
    if (apiLevel < 1 || apiLevel > 9) {
      println("Invalid API level!");
      exit();
    }
    API_LEVEL = apiLevel; //<>//
  }
  
  public void newByteIn(int dataByte) {    
    // If we are getting new bytes but we have already received all packets, then this is a new message so we need to RESET.
    if (allPacketsReceived) {
      allPacketsReceived = false;
      currentPlacements.clear();
    }
    
    // If the first byte of the packet is not a 1 then we have joined in halfway through, due to a corrupted message, or maybe some data was never even sent. In any case, skip.
    if (currentPacket.size() == 0 && dataByte != 1)
      return;
    
    currentPacket.add(dataByte);
    
    // 2nd byte contains length of message (1st byte is junk, always a 1).
    if (currentPacket.size() == 2) {
      // +5 because the length of message byte only gives the number of data bytes.
      // There are still 3 seperator bytes, plus 1 checksum byte, plus the message length byte itself. 3 + 1 + 1 = 5
      currentPacketLength = dataByte + 5;
    }
    else if (currentPacket.size() == currentPacketLength) {
      // If the packet is invalid then we only know that something went wrong, not what went wrong. So, clear all messages received to this point.
      if (!verifyAndParsePacket()) {
        currentPlacements.clear();
      }
      else {
        allPacketsReceived = isThisTheLastPacket();
      }
      
      currentPacket.clear();
      currentPacketLength = -1;
    }
  }
  
  // Returns true when full message received (all sub-messages received) and holds are ready to draw
  public boolean allPacketsReceived() {
    return allPacketsReceived;
  }
  
  public ArrayList<Hold> getCurrentPlacements() {
    return currentPlacements;
  }
  
  private boolean verifyAndParsePacket() {    
    // Checksum is not calculated with first 4 header bytes.
    // Checksum byte always the 3rd byte.
    if(checksum(currentPacket.subList(4, currentPacketLength - 1)) != (int)currentPacket.get(2)) {
      println("ERROR: checksum invalid");
      return false;
    }
    
    // If we are receiving a "first" packet when we already have data, or receiving a "non-first" packet when we don't have data,
    // then something has gone horribly wrong with transmission. Abort.
    if (currentPlacements.size() == 0 && !isThisTheFirstPacket() || currentPlacements.size() > 0 && isThisTheFirstPacket()) {
      print("ERROR: invalid packet order");
      return false;
    }
    
    // Start from i=5 as the first 4 bytes are a message header and the 5th byte indicates if this packet is at the start, middle or end of the message and has nothing to do with the hold data.
    
    if(API_LEVEL < 3) {
      // The data for each hold is 2 bytes, hence i+=2
      for(int i = 5; i < currentPacketLength - 1; i += 2) {
        int position = currentPacket.get(i) + ((currentPacket.get(i + 1) & 0b11) << 8);
        int clr[] = scaledColorToFullColorV2(currentPacket.get(i + 1));
        int coords[] = positions.get(position);
        if (coords == null) continue; // Skip this hold if invalid
        Hold h = new Hold(coords[0], coords[1], clr[0], clr[1], clr[2]);
        currentPlacements.add(h);
      }
    }
    else {
      // The data for each hold is 3 bytes, hence i+=3
      for(int i = 5; i < currentPacketLength - 1; i += 3) {
        int position = (currentPacket.get(i + 1) << 8) + currentPacket.get(i);
        int clr[] = scaledColorToFullColorV3(currentPacket.get(i + 2));
        int coords[] = positions.get(position);
        if (coords == null) continue; // Skip this hold if invalid
        Hold h = new Hold(coords[0], coords[1], clr[0], clr[1], clr[2]);
        currentPlacements.add(h);
      }
    }
    
    return true;
  }
  
  private boolean isThisTheFirstPacket() {
    // If the 4th byte of the message is a 'P' (80) or a 'T' (84) (depending on API level) then this is a single packet command, so this packet is first and last.
    // If the 4th byte is a 'N' (78) or an 'R' (82) (depending on API level) then this is the first packet of a multi packet command.
    if (API_LEVEL < 3) {
      return (currentPacket.get(4) == 80 || currentPacket.get(4) == 78);
    }
    else {
      return (currentPacket.get(4) == 84 || currentPacket.get(4) == 82);
    }
  }
  
  private boolean isThisTheLastPacket() {
    // If the 4th byte of the message is a 'P' (80) or a 'T' (84) (depending on API level) then this is a single packet command, so this packet is first and last.
    // If the 4th byte is a 'O' (79) or an 'S' (83) (depending on API level) then this is the last packet of a multi packet command.
    if (API_LEVEL < 3) {
      return (currentPacket.get(4) == 80 || currentPacket.get(4) == 79);
    }
    else {
      return (currentPacket.get(4) == 84 || currentPacket.get(4) == 83);
    }
  }
  
  // The AuroraBoard checksum algorithm
  private int checksum(java.util.List<Integer> list) {
    int i = 0;
    for (Integer intValue : list) {
        i = (i + intValue.intValue()) & 255;
    }
    return (~i) & 255;
  }
  
  // AuroraBoard color expander for API level 2 and below
  private int[] scaledColorToFullColorV2(int holdData) {
    int[] fullColor = new int[] {0,0,0};
    fullColor[2] = (int)(((holdData & 0b00001100) >> 2) / 3. * 255.);
    fullColor[1] = (int)(((holdData & 0b00110000) >> 4) / 3. * 255.);
    fullColor[0] = (int)(((holdData & 0b11000000) >> 6) / 3. * 255.);
    return fullColor;
  }
  
  // AuroraBoard color expander for API level 3 and above
  private int[] scaledColorToFullColorV3(int holdData) {
    int[] fullColor = new int[] {0,0,0};
    fullColor[2] = (int)(((holdData & 0b00000011) >> 0) / 3. * 255.);
    fullColor[1] = (int)(((holdData & 0b00011100) >> 2) / 7. * 255.);
    fullColor[0] = (int)(((holdData & 0b11100000) >> 5) / 7. * 255.);
    return fullColor;
  }
};
