byte led_g_pin = 5;  // Green led to show access, active HIGH, anode at pin 5
byte led_r_pin = 6;  // Red led to show locked, active HIGH, anode at pin 6
byte bolt_pin = 7;   // Pin to bolt, unlocked when HIGH, locked when LOW

String scratch = "";             // scratchpad string to feed new card data into
String master = "41003de765fe";  // this is the master value, if the card read is
                                 // this, open up (will make programming card later)

boolean open_flag = false;       // boolean flag to determine locked/unlocked

void setup(){
  Serial.begin(9600);            // set up serial to ID-20
  
  pinMode(led_g_pin, OUTPUT);    // Set pins to output
  pinMode(led_r_pin, OUTPUT);
  pinMode(bolt_pin, OUTPUT);
  
  digitalWrite(bolt_pin, LOW);   // Force bolt closed on start
  digitalWrite(led_r_pin, HIGH); // turn on locked led by default
}

void loop(){
  if ( Serial.available() >= 16 ){getNumber();} // if data waiting, see to it
  
  if (open_flag){                              // if flagged to open
    digitalWrite(led_r_pin, LOW);              // twiddle the leds
    digitalWrite(led_g_pin, HIGH);
    digitalWrite(bolt_pin, HIGH);              // open the bolt
    delay(2500);                               // wait a moment
    digitalWrite(bolt_pin, LOW);               // and close
    digitalWrite(led_g_pin, LOW);              // reset the leds
    digitalWrite(led_r_pin, HIGH);
    open_flag = false;                         // and reset the flag
  }
}

void getNumber(){
  scratch = "";    // clear scratch for a new scan
  /* Data takes form:
   *
   * +---------+----+----+----+----+----+----+----+----+----+-----+----+----+---------+---------+---------+
   * | 2 (STX) | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | D9 | D10 | C1 | C2 | 13 (CR) | 10 (LF) | 3 (ETX) |
   * +---------+----+----+----+----+----+----+----+----+----+-----+----+----+---------+---------+---------+
   *
  */
  
  char c = Serial.read();               // get the first character
  
  while (c != 2){c = Serial.read();}    // if its not STX, keep going till it is
                                        // (though this is bad!)
  if (c == 2){                          // now that we have STX
    while ( c != 3 ){                   // loop through all new date till we get ETX
      c = Serial.read();
      scratch += c;                     // and append it to scratch
    }
  }
  
  scratch = scratch.replace(13, '\0');    // clean away 
  scratch = scratch.replace(10, '\0');
  scratch = scratch.toLowerCase();
  
  if (scratch == master){
    open_flag = true;
  }
}
