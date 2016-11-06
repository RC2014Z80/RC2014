/* SD Memory Dump Plus
 *  Firmware for the RC2014 module
 *  Module by Spencer Owen
 *  
 *  Original version of the source by Spencer Owen
 *  This version - yorgle@gmail.com Scott Lawrence
 */

#include <SPI.h>
#include <SD.h>

/*
 * Revision History
 * 1.02 - 11/05/2016 - Pot selects file to load/save, red LED indicates which of 7 files
 * 1.01 - 11/05/2016 - Refactoring, adding in potentiometer selector
 * 1.00 - 11/04/2016 - Provided from Spencer Owen, initial functionality
 */
const char * versionString = "v1.02 - 11/05/2016";


/* NOTE: in the v1 hardware, it is impossible to program the AVR in-circuit
 *       without modifying the circuit.  The modification is to disconnect
 *       pin 2 of the AVR from the circuit, and connect it directly to 
 *       JP3 pin 4 (TX) of the FTDI connector.
 *       
 *       The nicer way to do this is to pull pin 2 of the AVR from the socket,
 *       and connect it to the center pole of a 3 pin header.  One side of the 
 *       header should go to the BUSACK bus ("usage mode") and the other side
 *       of the header should go to pin 4 of the FTDI connector, which has been
 *       isolated from the circuit board. ("programming mode")
 */

/* Known issues:
 *  - The arduino SD library cannot deal with cards changing and will fail
 *    on reads after the card has been changed. The only way around this is to
 *    do a hard reset after the card is removed.
 *    
 *    A possible solution:
 *      - do a "is card available" check, occasionally.
 *      - if the call fails, error code on the LED, then hard reset resetFunc()
 *      - I did a version of this for another project and it worked well
 */

/* pin usage of the arduino */
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


int z = 0;  //null value for delay

void resetFunc()
{
  asm volatile ("jmp 0");
}


void setup() {
  pinMode( kPin_COUNT, OUTPUT );
  pinMode( kPin_CRESET, OUTPUT );
  pinMode( kPin_DONE, OUTPUT );
  digitalWrite( kPin_CRESET, HIGH );
  digitalWrite( kPin_DONE, LOW );
  pinMode( kPin_DATA0, INPUT );
  pinMode( kPin_DATA1, INPUT );
  pinMode( kPin_DATA2, INPUT );
  pinMode( kPin_DATA3, INPUT );
  pinMode( kPin_DATA4, INPUT );
  pinMode( kPin_DATA5, INPUT );
  pinMode( kPin_DATA6, INPUT );
  pinMode( kPin_DATA7, INPUT );
  pinMode( kPin_WRTOGGLE, OUTPUT );
  digitalWrite( kPin_WRTOGGLE, HIGH );
  
  pinMode( kPin_WRREQ, INPUT );

  pinMode( kPin_SELECT, INPUT );

  Serial.begin( 115200 );
  //Serial.print("Initializing SD card...");

  if( !SD.begin(10) ) {
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

#define kPos_SW (0)
#define kPos_W  (1)
#define kPos_NW (2)
#define kPos_N  (3)
#define kPos_NE (4)
#define kPos_E  (5)
#define kPos_SE (6)

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

/* We've configured this such that for SW,W,NW, and N, you
 * cannot overwrite the ROM files, but you can still dump 
 * to the card.  for NE, E, and SE, you can re-load the 
 * dumps you've created previously.
 */
const char * filenamesLoad[7] = {
  "ROM_SW.bin",
  "ROM_W.bin",
  "ROM_NW.bin",
  "ROM_N.bin",
  
  "Dump_NE.bin",
  "Dump_E.bin",
  "Dump_SE.bin"
};

const char * filenamesSave[7] = {
  "Dump_SW.bin",
  "Dump_W.bin",
  "Dump_NW.bin",
  "Dump_N.bin",
  "Dump_NE.bin",
  "Dump_E.bin",
  "Dump_SE.bin"
};

/* these are used by the pollLed() function to display a 
 *  selection pattern on the RED LED.
 *  The strings consist of 'l' and 's' and ','
 *  'l' is a long flash
 *  's' is a short flash
 *  'D' is a long delay
 *  'd' is a short delay
 */
const  char * ledPatterns[7] = {
  "sD", "sdsD", "sdsdsD", "lD", "ldsD", "ldsdsD", "ldsdsdsD"
};


void pollLed() {
  static long stepTimeout = 0;
  static int patternStep = 0;
  static int ledState = LOW;
  static int lastValue = -1;
  
  int value = convertPotValue();

  if( value != lastValue ) {
    /* new value, reset the animation */
    lastValue = value;
    patternStep = -1;
    stepTimeout = 0; /* force an update next */
  }

  if( millis() > stepTimeout ) {
    patternStep++;
    if( ledPatterns[value][patternStep] == '\0' ) {
      /* past the end of the pattern */
      patternStep = 0; /* reset */
    }
    switch( ledPatterns[value][patternStep] ) {
      case( 's' ):
        ledState = HIGH;
        stepTimeout = millis() + 100;
        break;
      case( 'l' ):
        ledState = HIGH;
        stepTimeout = millis() + 400;
        break;
      case( 'd' ):
        stepTimeout = millis() + 100;
        ledState = LOW;
        break;
      case( 'D' ):
        stepTimeout = millis() + 1000;
        ledState = LOW;
        break;
    }
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

/* Load From SD card */
void SD2Bus() {
  File myFile;
  int dataByte = 0;
  
  //Serial.print ("writing from SD card to the bus");
  myFile = SD.open( filenamesLoad[ convertPotValue() ] );
  
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
    for (long i = 0; i < 65535 && myFile.available() ; i++) { // change to stop at EOF!
      dataByte = myFile.read();
      //Serial.print (char(dataByte));
      digitalWrite(kPin_DATA0, (dataByte & 0x01) == 0x01 ? HIGH : LOW );
      digitalWrite(kPin_DATA1, (dataByte & 0x02) == 0x02 ? HIGH : LOW );
      digitalWrite(kPin_DATA2, (dataByte & 0x04) == 0x04 ? HIGH : LOW );
      digitalWrite(kPin_DATA3, (dataByte & 0x08) == 0x08 ? HIGH : LOW );
      digitalWrite(kPin_DATA4, (dataByte & 0x10) == 0x10 ? HIGH : LOW );
      digitalWrite(kPin_DATA5, (dataByte & 0x20) == 0x20 ? HIGH : LOW );
      digitalWrite(kPin_DATA6, (dataByte & 0x40) == 0x40 ? HIGH : LOW );
      digitalWrite(kPin_DATA7, (dataByte & 0x80) == 0x80 ? HIGH : LOW );
      
      int z = digitalRead(kPin_WRREQ);
      //delay(1);
      digitalWrite(kPin_WRTOGGLE, LOW);
      //delay(1);
      digitalWrite(kPin_WRTOGGLE, HIGH);


      //      Buswrite( dataByte );
      //delay(5);
      digitalWrite(kPin_COUNT, HIGH);
     // delay(1);
      digitalWrite(kPin_COUNT, LOW);
      //delay(1);
    }

    myFile.close();
  }
  //Serial.println();
  //Serial.print ("Memory writen");
  digitalWrite(kPin_DONE, HIGH);
  int z = digitalRead(kPin_WRREQ); /* shouldn't this be checked? */
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

/* save ram to SD file. */
void Read2SD() {
  File myFile;
  int dataByte = 0;
  
  Serial.println("memory to SD");
  myFile = SD.open(filenamesSave[ convertPotValue() ] , FILE_WRITE);
  if (myFile) {
    digitalWrite(kPin_CRESET, HIGH);
    delay(1);
    digitalWrite(kPin_CRESET, LOW);
    for (long i = 0; i < 65535; i++) {
      dataByte = ( (digitalRead(kPin_DATA0)==HIGH ? 0x01 : 0 ) 
                 + (digitalRead(kPin_DATA1)==HIGH ? 0x02 : 0 )
                 + (digitalRead(kPin_DATA2)==HIGH ? 0x04 : 0 )
                 + (digitalRead(kPin_DATA3)==HIGH ? 0x08 : 0 )
                 + (digitalRead(kPin_DATA4)==HIGH ? 0x10 : 0 )
                 + (digitalRead(kPin_DATA5)==HIGH ? 0x20 : 0 )
                 + (digitalRead(kPin_DATA6)==HIGH ? 0x40 : 0 ) 
                 + (digitalRead(kPin_DATA7)==HIGH ? 0x80 : 0 )
                 );
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


