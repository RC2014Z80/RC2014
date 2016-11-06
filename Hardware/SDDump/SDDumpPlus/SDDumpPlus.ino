/* SD Memory Dump
 *  Firmware for the RC2014 module
 *  Module by Spencer Owen
 *  Original version of the source by Spencer Owen
 *  
 *  This version - yorgle@gmail.com Scott Lawrence
 */

/*
 * Revision History
 * 1.01 - 11/05/2016 - Refactoring, adding in potentiometer selector
 * 1.00 - 11/04/2016 - Provided from Spencer Owen, initial functionality
 */

#include <SPI.h>
#include <SD.h>

File myFile;


#define kPin_WRREQ      14  /* A0 */
#define kPin_WRTOGGLE   15  /* A1 */
#define kPin_DONE       16  /* A2 */
#define kPin_SELECT     A3  /* 17 */
#define kPin_CRESET     18  /* A4 */
#define kPin_COUNT      19  /* A5 */
#define kPin_LED        19  /* same as COUNT */
#define kPin_BUSACK     0
#define kPin_DATA0      9
#define kPin_DATA1      2
#define kPin_DATA2      3
#define kPin_DATA3      4
#define kPin_DATA4      5
#define kPin_DATA5      6
#define kPin_DATA6      7
#define kPin_DATA7      8

int dataByte = 0;
int z = 0;  //null value for delay


void setup() {
  pinMode(kPin_COUNT, OUTPUT);
  pinMode(kPin_CRESET, OUTPUT);
  pinMode(kPin_DONE, OUTPUT);
  digitalWrite(kPin_CRESET, HIGH);
  digitalWrite(kPin_DONE, LOW);
  pinMode(kPin_DATA0, INPUT);
  pinMode(kPin_DATA1, INPUT);
  pinMode(kPin_DATA2, INPUT);
  pinMode(kPin_DATA3, INPUT);
  pinMode(kPin_DATA4, INPUT);
  pinMode(kPin_DATA5, INPUT);
  pinMode(kPin_DATA6, INPUT);
  pinMode(kPin_DATA7, INPUT);
  pinMode(kPin_WRTOGGLE, OUTPUT);
  digitalWrite(kPin_WRTOGGLE, HIGH);
  pinMode(kPin_WRREQ, INPUT);

  pinMode( kPin_SELECT, INPUT );

  Serial.begin(115200);
  //Serial.print("Initializing SD card...");

  if (!SD.begin(10)) {
    //Serial.println("initialization failed!");
    return;
  }
  //Serial.println("initialization kPin_DONE.");
}


/* Values of the potentiometer (rough)
 *  
 *  SW     0  1 (full ACW)
 *   W    80  2
 *  NW   305  3
 *  N    500  4
 *  NE   725  5
 *   E   950  6
 *  SE  1020  7 (full CW)
 *  
 */

#define kPos_SW (1)
#define kPos_W  (2)
#define kPos_NW (3)
#define kPos_N  (4)
#define kPos_NE (5)
#define kPos_E  (6)
#define kPos_SE (7)

int convertPotValue()
{
  int value = analogRead( kPin_SELECT );
  if( value < 50 ) return kPos_SW;
  if( value < 250 ) return kPos_W;
  if( value < 400 ) return kPos_NW;
  if( value < 680 ) return kPos_N;
  if( value < 900 ) return kPos_NE;
  if( value < 1010 ) return kPos_E;
  return kPos_SE;
}

void pollLed() {
  static long lastChangeTime = 0;
  static int ledState = LOW;
  static int lastValue = -1;
  
  int value = convertPotValue();

  if( value != lastValue ) {
    lastValue = value;
    Serial.println( value, DEC );
  }

  if( millis() > lastChangeTime + value ) {
    lastChangeTime = millis();
    ledState = (ledState==HIGH)?LOW:HIGH;
  }

  digitalWrite( kPin_LED, ledState );
}

void loop() {
  pollLed();
  
  digitalWrite(kPin_CRESET, LOW);
  digitalWrite(kPin_DONE, LOW);
  
  if (digitalRead (kPin_BUSACK) == 0) {
    if (digitalRead (kPin_WRREQ) != 0) {
      Read2SD();
    }
    else {
      SD2Bus();
    }
  }
}

void SD2Bus() {
  //Serial.print ("writing from SD card to the bus");
  myFile = SD.open("LOADFILE.hex");
  
  if (myFile) {
    pinMode(kPin_WRTOGGLE, OUTPUT);
    digitalWrite(kPin_WRTOGGLE, LOW);
    pinMode(kPin_DATA0, OUTPUT);
    pinMode(kPin_DATA1, OUTPUT);
    pinMode(kPin_DATA2, OUTPUT);
    pinMode(kPin_DATA3, OUTPUT);
    pinMode(kPin_DATA4, OUTPUT);
    pinMode(kPin_DATA5, OUTPUT);
    pinMode(kPin_DATA6, OUTPUT);
    pinMode(kPin_DATA7, OUTPUT);
    digitalWrite(kPin_CRESET, HIGH);
    int z = digitalRead(kPin_WRREQ);
    //delay(1);
    digitalWrite(kPin_CRESET, LOW);
    for (long i = 0; i < 65535; i++) {
      dataByte = myFile.read();
      //Serial.print (char(dataByte));
      digitalWrite(kPin_DATA0, dataByte & 0x01);
      digitalWrite(kPin_DATA1, dataByte & 0x02);
      digitalWrite(kPin_DATA2, dataByte & 0x04);
      digitalWrite(kPin_DATA3, dataByte & 0x08);
      digitalWrite(kPin_DATA4, dataByte & 0x10);
      digitalWrite(kPin_DATA5, dataByte & 0x20);
      digitalWrite(kPin_DATA6, dataByte & 0x40);
      digitalWrite(kPin_DATA7, dataByte & 0x80);
      int z = digitalRead(kPin_WRREQ);
      //delay(1);
      digitalWrite(kPin_WRTOGGLE, LOW);
      //delay(1);
      digitalWrite(kPin_WRTOGGLE, HIGH);


      //      Buswrite();
      //delay(5);
      digitalWrite(kPin_COUNT, HIGH);
     // delay(1);
      digitalWrite(kPin_COUNT, LOW);
      //delay(1);
    }
  }
  //Serial.println();
  //Serial.print ("Memory writen");
  digitalWrite(kPin_DONE, HIGH);
  int z = digitalRead(kPin_WRREQ);
  delay(1);
  digitalWrite(kPin_DONE, LOW);

  pinMode(kPin_DATA0, INPUT);
  pinMode(kPin_DATA1, INPUT);
  pinMode(kPin_DATA2, INPUT);
  pinMode(kPin_DATA3, INPUT);
  pinMode(kPin_DATA4, INPUT);
  pinMode(kPin_DATA5, INPUT);
  pinMode(kPin_DATA6, INPUT);
  pinMode(kPin_DATA7, INPUT);
  digitalWrite(kPin_WRTOGGLE, HIGH);
  //Serial.println("kPin_DONE.");

}

void Read2SD() {
  Serial.println("memory to SD");
  myFile = SD.open("SaveFile.hex", FILE_WRITE);
  if (myFile) {
    digitalWrite(kPin_CRESET, HIGH);
    delay(1);
    digitalWrite(kPin_CRESET, LOW);
    for (long i = 0; i < 65535; i++) {
      dataByte = ((digitalRead(kPin_DATA0)) + (digitalRead(kPin_DATA1) * 2) + (digitalRead(kPin_DATA2) * 4) + (digitalRead(kPin_DATA3) * 8) + (digitalRead(kPin_DATA4) * 16) + (digitalRead(kPin_DATA5) * 32) + (digitalRead(kPin_DATA6) * 64) + (digitalRead(kPin_DATA7) * 128));
      //Busread();
      myFile.print(char(dataByte));
      //Serial.print(char(dataByte));
      dataByte = 0;
      digitalWrite(kPin_COUNT, HIGH);
      delay(1);
      digitalWrite(kPin_COUNT, LOW);
      //delay(1);
    }
    digitalWrite(kPin_CRESET, HIGH);
    myFile.close();
  }
  digitalWrite(kPin_DONE, HIGH);
  delay(1);
  digitalWrite(kPin_DONE, LOW);
  //Serial.println("kPin_DONE.");
}

void Busread() {
  delay(1);
  dataByte = ((digitalRead(kPin_DATA0)) + (digitalRead(kPin_DATA1) * 2) + (digitalRead(kPin_DATA2) * 4) + (digitalRead(kPin_DATA3) * 8) + (digitalRead(kPin_DATA4) * 16) + (digitalRead(kPin_DATA5) * 32) + (digitalRead(kPin_DATA6) * 64) + (digitalRead(kPin_DATA7) * 128));
}

void Buswrite() {
  //digitalWrite(kPin_WRTOGGLE, LOW);
  digitalWrite(kPin_DATA0, dataByte & 0x01);
  digitalWrite(kPin_DATA1, dataByte & 0x02);
  digitalWrite(kPin_DATA2, dataByte & 0x04);
  digitalWrite(kPin_DATA3, dataByte & 0x08);
  digitalWrite(kPin_DATA4, dataByte & 0x10);
  digitalWrite(kPin_DATA5, dataByte & 0x20);
  digitalWrite(kPin_DATA6, dataByte & 0x40);
  digitalWrite(kPin_DATA7, dataByte & 0x80);
  delay(1);
  digitalWrite(kPin_WRTOGGLE, LOW);
  delay(1);
  digitalWrite(kPin_WRTOGGLE, HIGH);
}


