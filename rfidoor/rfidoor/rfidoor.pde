#include <SoftwareSerial.h>

/*
Coding contributions by :
Abstractbeliefs, 'Orum, Zhanx, Scgtrp, Dtrickie


this code is for an RFID entry system that
allows you to open the door via RFID tag
or the internet / LAN
it stores the authorized codes on the micro SD card
once the access is authorized the door unlocks for 2.5 seconds
then the relay controlling an outlet is turned on controlling a light



pins 5,6 Red/Green Led
pin 0  to N/C push button to ID-20 signal
pin 7 to relay for electric strike
reset to N/O push button to ground
pin A2 to relay for outlet
*/


#include <SoftwareSerial.h>
#include <SPI.h>
#include <Client.h>
#include <Ethernet.h>
#include <Server.h>
#include <Udp.h>
#include <SD.h>
#define FILENAME "cards.txt"
SoftwareSerial mySerial(2, 3);

byte mac[] = {
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED }; //physical mac address
byte ip[] = {
  192,168,1,205 };	 // ip in lan
byte gateway[] = {
  //192, 168, 1, 1 };// internet access via router
  192,168,1,1 };	 // internet access via ethernet connection on mac
byte subnet[] = {
  255, 255, 255, 0 }; //subnet mask
Server server(80); //server port

byte
led_g_pin = 5,	// Green led to show access, active HIGH, anode at pin 5
led_r_pin = 6,	// Red led to show locked, active HIGH, anode at pin 6
bolt_pin = 7,	// Pin to bolt, unlocked when HIGH, locked when LOW
ext_pin = 16,    // external pin. On pin A0
scratch[16] = { 
  2 }
,		// scratchpad string to feed new card data into
master[10] = { 
  //Enter your master card code here
  'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X', 'X' };	// this is the master value, if the card read is this, open up (Used for programming )

boolean
open_flag = false,	// boolean flag to determine locked/unlocked
ext_on_flag = false;    // booloan flag to determine external on/off

unsigned long trig_time;
unsigned long end_time;

String readString = String(30); //string for fetching data from address
void setup(){
  Serial.begin(9600);					// set up serial to ID-20
  Ethernet.begin(mac, ip, gateway, subnet);               //start Ethernet
  pinMode(10, OUTPUT);					// select SD card
  if (!SD.begin(4)) {					// Make sure the SD card works
    Serial.println("SD card failure");
    return;
  }

  File touch = SD.open(FILENAME, FILE_WRITE);	// create the file if it's not already there
  touch.close();

  pinMode(led_g_pin, OUTPUT);		// Set pins to output
  pinMode(led_r_pin, OUTPUT);
  pinMode(bolt_pin, OUTPUT);
  pinMode(ext_pin, OUTPUT);

  digitalWrite(bolt_pin, LOW);		// Force bolt closed on start
  digitalWrite(led_r_pin, HIGH);	// turn on locked led by default
}

void loop(){
  if (ext_on_flag){                 // if its time to turn on the ext
    trig_time = millis();           // for the overflow check
    end_time = trig_time + 600000;  // end in +10mins
    digitalWrite(ext_pin, HIGH);    // and power the ext
    Serial.println("ext_pin is HIGH");
    ext_on_flag = false;
  }

  if (millis() >= end_time){      // if its time to turn of ext
    digitalWrite(ext_pin, LOW);   // simply turn it off
    Serial.println("ext_pin is LOW");
  }

  if (millis() < trig_time){      // WHOOPS! We've gone back in time (or overflowed millis)
    end_time = millis() + 300000; // turn of the ext in 5 mins. simplest solution.
  }

  if (Serial.available() > 10){
    getNumber();
    getPermissions();
  }

  WebServer();

  if(open_flag) {	// if flagged to open
    openup();           // open the door
  }
}

void openup(){
  digitalWrite(led_r_pin, LOW);		// twiddle the leds
  digitalWrite(led_g_pin, HIGH);
  digitalWrite(bolt_pin, HIGH);		// open the bolt
  delay(2500);                          // wait a moment
  digitalWrite(bolt_pin, LOW);		// and close
  digitalWrite(led_g_pin, LOW);		// reset the leds
  digitalWrite(led_r_pin, HIGH);
  open_flag = false;                    // and reset the flag
}

void getNumber(){
  /* Data takes form:
   	 *
   	 * +---------+----+----+----+----+----+----+----+----+----+-----+----+----+---------+---------+---------+
   	 * | 2 (STX) | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | D9 | D10 | C1 | C2 | 13 (CR) | 10 (LF) | 3 (ETX) |
   	 * +---------+----+----+----+----+----+----+----+----+----+-----+----+----+---------+---------+---------+
   	 *	
   	*/

  int last;

  do {
    last = Serial.read();
  } 
  while(last != 2);			// read until we get a STX

  byte idx = 1;					// position in scratch where the next byte goes

  do {
    last = Serial.read();

    if(last >= 0 && last <= 0xFF)	// Make sure we don't get an error when reading from serial
      scratch[idx++] = last;
  } 
  while(idx < 16);			// keep reading til we have all 16 bytes

  // Convert D1-C2 to capital letters
  for(byte x = 1; x < 13; x++)
    if(scratch[x] >= 'a' && scratch[x] <= 'f')
      scratch[x] -= 32;

  // TODO: verify checksum & formatting
}

long checkCard(File cards) {
  long location = cards.position();					// save our current location to be restored when we return
  cards.seek(0);												// goto start of cards

  byte tmp[10];												// buffer to hold one card ID copied from the file on the SD card
  long num_cards = (cards.size() / 10);				// number of cards is number of characters in file, divided by 10

    for(long i = 0; i < num_cards; i++) {				// for every card
    for(byte j = 0; j < 10; j++)						// read the 10 digits
      tmp[j] = cards.read();							// read the current byte

    if(!memcmp(&scratch[1], tmp, sizeof(tmp))) {	// does the current card ID match one in the file?
      cards.seek(location);							// restore saved location
      return (i * 10);									// found a match
    }
  }																// open the lock

  cards.seek(location);									// restore saved location
  return -1;													// no match found
}

void getPermissions(){
  File cards;

  //                    ************** PROGRAMMING MODE **************
  if(!memcmp(&scratch[1], master, sizeof(master))) {	// Is this the master card?
    // flickers led to indicate that it is in programming mode
    for (int i = 0; i <= 5; i++){
      digitalWrite(led_r_pin, HIGH);
      digitalWrite(led_g_pin, LOW);
      delay (100);
      digitalWrite(led_r_pin, LOW);
      digitalWrite(led_g_pin, HIGH);
      delay (100);
    }

    getNumber();											// Read next card
    cards = SD.open(FILENAME, FILE_WRITE);			// open the cards permission file
    long loc = checkCard(cards);						// check if card exists in the file already

    if(loc == -1) {										// new card not presently in the file
      long x;
      long len = cards.size();						// store our size

        for(x = 0; x < len; x += 10) {				// Find our first overwritten card, or the end of the file
        cards.seek(x);

        if(cards.read() == '-')
          break;
      }

      cards.seek(x);										// Seek to where we want to write
      cards.write(&scratch[1], 10);					// write new card to the end of the file or over the first '----------'
    }
    else {													// card was already there, so get rid of it
      byte blank[10] = { 
        '-', '-', '-', '-', '-', '-', '-', '-', '-', '-'             };

      cards.seek(loc);
      cards.write(blank, 10);
    }
    // flickers led to verify that programming is complete
    for (int i = 0; i <= 5; i++){
      digitalWrite(led_r_pin, LOW);
      digitalWrite(led_g_pin, HIGH);
      delay (100);
      digitalWrite(led_r_pin, HIGH);
      digitalWrite(led_g_pin, LOW);
      delay (100);
    }
  }
  ////////////////////////// END PROGRAMMING MODE

  ////////////////////////// PERMISSION MODE
  else {
    cards = SD.open(FILENAME, FILE_READ);			// open the cards permission file

    if(checkCard(cards) != -1)							// if we found a match
      open_flag=true;									// set our flag
    ext_on_flag=true;
  }

  cards.close();		// clean up, finalize any writing
  /* Relocated following code to loop.
   // Create a client connection
   //WebServer();
   */
} 


void WebServer()
{
  Client client = server.available();
  if (client) {
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();

        //read char by char HTTP request
        if (readString.length() < 30) {

          //store characters to string 
          readString.concat(c);

        } 

        //output chars to serial port
        Serial.print(c);

        //if HTTP request has ended
        if (c == '\n') {
          ReadInput(readString);
          // Header Code 
          HtmlHeader(client);
          // Body Code
          HtmlBody(client);
          // Footer Code
          HtmlFooter(client);


          //clearing string for next read
          readString="";

          //stopping client
          client.stop();
        }
      }
    }
  }
}

void HtmlHeader(Client client)
{
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: text/html");
  client.println();
  client.println("<HTML>\n<HEAD>");
  client.println("  <TITLE>RFIDoor Web Interface</TITLE>");//
  client.println("</HEAD><BODY bgcolor=\"#9bbad6\">");
}

void HtmlBody(Client client)
{
  client.print("Click to open door:");
  SubmitButton(client, "OPEN", 1);
}

void HtmlFooter(Client client)
{
  client.println("</BODY></HTML>");
}

void SubmitButton(Client &client, char *pcLabel, int iCmd)
{
  client.println("<form method=get name=OPEN><input type=submit name=L1 value=OPEN><form>");
}

void ReadInput(String buffer)
{
  if (buffer.substring(6,13) =="L1=OPEN")
  {
    open_flag=true;
    ext_on_flag=true;
  }
}

