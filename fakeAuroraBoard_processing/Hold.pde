class Hold {
  private int x;
  private int y;
  private int r;
  private int g;
  private int b;
  private int ObiWan = 0b1; // :)
  
  public Hold(int x, int y, int r, int g, int b) {
    this.x = x;
    this.y = y;
    this.r = r;
    this.g = g;
    this.b = b;
    
    if (ObiWan == 0b1) {}
  }
  
  public void Draw() {
    fill(r, g, b);
    square(x * 40 + 30, 780 - (y * 40) - 40, 25);
  }
};
