



//Code:
#include <SPI.h>
#include <String.h>
#include <Ethernet.h>




byte mac[] = {
  0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED }; //physical mac address
byte ip[] = {
  4,26,78,205 };	 // ip in lan
byte gateway[] = {
  //192, 168, 1, 1 };// internet access via router
  4,26,78,1 };	 // internet access via ethernet connection on mac
byte subnet[] = {
  255, 255, 255, 0 }; //subnet mask
Server server(80); //server port
int ledPin = 9; // LED pin

String readString = String(30); //string for fetching data from address

boolean LEDON = false; //LED status flag

 void setup()
{
  //start Ethernet
  Ethernet.begin(mac, ip, gateway, subnet);
  //Set pin 4 to output
    pinMode(ledPin, OUTPUT);
  //enable serial data print
  Serial.begin(9600);

}



void loop()

{
  // Create a client connection
  Client client = server.available();
  if (client) {
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();

        //read char by char HTTP request
        if (readString.length() < 30)
        {
          readString += c; //store characters to string
        }
        //if HTTP request has ended
        if (c == '\n')

        {
          // check if LED should be lighted

          delay(1000);
          int locateQuestionmark = readString.indexOf('?');
          Serial.println (readString);
          Serial.println ("The index of the ? in the string " + readString + " is " + locateQuestionmark);


          if (readString.substring(6,9) == "L=1")      

          {
            //led has to be turned ON
            digitalWrite(ledPin, HIGH); // set the LED on
            //delay(1000);
            LEDON = true;
            Serial.println( "ON");
          }

          else

          {
            //led has to be turned OFF
            digitalWrite(ledPin, LOW); // set the LED OFF
            Serial.println ("off");
            LEDON = false;
          }






          // now output HTML data starting with standart header
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println();
          //set background to yellow
          client.print("<body style=background-color:black>");

          //send first heading
          client.println("<font color=’red’><h1>  WEB LIGHTS</font></h1>");
          client.println("<hr />");
          client.println("<hr />");

          //controlling led via checkbox
          client.println("<font color=’blue’><h1>Light control</h1>");
          //address will look like http://192.168.1.110/?L=1 when submited
          //client.println("<form method=get name=LED><input type=checkbox name=L value=1>LED<br><input type=submit value=submit></form>");
          client.println("<font color=’blue’><form method=get name=LED><input type=checkbox name=L value=1>LIGHT<br><input type=submit value=submit></form>");
          client.println("<br />");

          //printing LED status
          client.print("<font color=’blue’><font size=’5′>light status: ");
          if (LEDON)
            client.println("<font color=’green’ size=’5′>ON");
          else
            client.println("<font color=’red’ size=’5′>OFF");
          client.println("<hr />");
          client.println("<hr />");
          client.println("To turn on check box and submit");
          client.println("<hr />");
          client.println("To turn off clear check box and submit");
          client.println("</body></html>");
          //clearing string for next read
          readString="";
          //stopping client
          client.stop();
        }



      }



    }




  }
}
//*******************************



 


