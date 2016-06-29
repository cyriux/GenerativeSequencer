/*
 * 
 *
 *
 *
 *
 * Creative Commons License Cyrille Martraire cyrille.martraire.com
 */

// DEBUG
int debug = false;

//---------- USER INPUT AND PAGINATION -----------
#define PAGE_NB 4
#define KNOB_NB 6
#define FIRST_PAGE_BUTTON 8

#define PROTECTED -1
#define ACTIVE 1

#define SYNC_LED 12

// the permanent storage of every value for every page, used by the actual music code
int pageValues[PAGE_NB][KNOB_NB];

// last read knob values
int knobsValues[KNOB_NB];
// knobs state (protected, enable...)
int knobsStates[KNOB_NB];
// current (temp) value just read
int value = 0;
// the current page id of values being edited
int currentPage = 0;
// signals the page change
boolean pageChange = false;
//temp variable to detect when the knob's value matches the stored value
boolean inSync = false;

//---------- GENERATIVE MUSIC CODE ---------
int cursor = 0;
int cursor2 = 0;
int bars = 1;
int length = bars * 4 * 24;
int loopPeriod = 125/6;//120BPM

int notes[32]; 
int lastNote = 0;

int quotient = 0;
int remainer = 0;

// INPUTS

//
int SHIFT = 0;
int STRETCH = 1;
//int DIRECTION = 2;
int NOTE = 2;
int DURATION = 3;
int VELOCITY = 4;
int CHANNEL = 5;

// seed
int seedTimes = 8;
int seedDuration = 24;

//instance i
int shift = 0;
int stretch = 1;
int note = 48;
int duration = 24;
int velocity = 100;
int channel = 1;

void setup(){
  if(debug){
   Serial.begin(19200); //debug
  } else {
    Serial.begin(31250);
  }
  
  pinMode(13, OUTPUT);
  setupPagination();
}

      
       
void loop () {
    midiClock();
    
    poolInputWithPagination();
    //printAll();
        
    //reference steady beat 4 on the floor
    if (cursor % 24 == 0){
      noteOn(0x90, 72, 127); // steady beat 4 on the floor
    }
    
    // global parameters
    seedTimes = map(pageValues[0][0], 0, 890, 0, 32);
    seedDuration = map(pageValues[0][1], 0, 890, 6, 96);
    loopPeriod = map(pageValues[0][5], 0, 890, 63, 13);// 12.5 ms - 62.5
    
    // parameters for each instance (pages 1 to 3)
    for(int index = 1; index < PAGE_NB; index++){
        processSeeInstance(pageValues[index]);
    }
    
    // instance 1
    if(isBeat(cursor, seedTimes, seedDuration)) {// once every 2 bar
          //noteOn(0x90, note1, 100);
    }
    
    // instance 2
    //if(isBeat(cursor * stretch2 / 24 - (shift2 * 6), seedTimes, seedDuration)) {// once every 2 bar
          //noteOn(0x90, note2, 100);
    //}
    
    cursor = (cursor + 1) % length;
    delay(loopPeriod);
}

void processSeeInstance(int * params){
  shift = map(params[SHIFT], 0, 890, 0, 32);
  stretch = map(params[STRETCH], 0, 890, 6, 96);
  note = map(params[NOTE], 0, 890, 36, 60);
  duration = map(params[DURATION], 0, 890, 6, 96);
  velocity = map(params[VELOCITY], 0, 890, 0, 127);
  channel = map(params[CHANNEL], 0, 890, 0, 16);
  
  if(isBeat(cursor * stretch / 24 - (shift * 6), seedTimes, seedDuration)) {
     noteOn(0x90 | (channel<<4), note, velocity);
  }
}

// for each cursor location, find out whether we are on a pulse or not according to the seed
boolean isBeat(int cursor, byte times, byte duration){
  if (cursor / duration >= times){
    return false;
  }
  return cursor % duration == 0;
}

//24 ticks per quarter
void midiClock(){
  Serial.print(0xF8, BYTE);
}

void noteOn(char cmd, char data1, char data2) {
  if(debug){
    return;
  }
  Serial.print(cmd, BYTE);
  Serial.print(data1, BYTE);
  Serial.print(data2, BYTE);
}

//********************************************

void setupPagination(){
  pinMode(SYNC_LED, OUTPUT);
  for(int i=0; i < KNOB_NB; i++){
    knobsValues[i] = analogRead(i);
    knobsStates[i] = ACTIVE;
  }
}

// read knobs and digital switches and handle pagination
void poolInputWithPagination(){
  // read page selection buttons
  for(int i = FIRST_PAGE_BUTTON;i < FIRST_PAGE_BUTTON + PAGE_NB; i++){
     value = digitalRead(i);
     if(value == LOW){
         pageChange = true;
         currentPage = i - FIRST_PAGE_BUTTON;
     }
  }
  // if page has changed then protect knobs (unfrequent)
  if(pageChange){
    pageChange = false;
    digitalWrite(SYNC_LED, LOW);
    for(int i=0; i < KNOB_NB; i++){
      knobsStates[i] = PROTECTED;
    }
  }
  // read knobs values, show sync with the LED, enable knob when it matches the stored value
  for(int i = 0;i < KNOB_NB; i++){
     value = analogRead(i);
     inSync = abs(value - pageValues[currentPage][i]) < 20;
     
     // enable knob when it matches the stored value
     if(inSync){
        knobsStates[i] = ACTIVE;
     }
     
     // if knob is moving, show if it's active or not
     if(abs(value - knobsValues[i]) > 5){
          // if knob is active, blink LED
          if(knobsStates[i] == ACTIVE){
            digitalWrite(SYNC_LED, HIGH);
          } else {
            digitalWrite(SYNC_LED, LOW);
          }
     }
     knobsValues[i] = value;
     
     // if enabled then miror the real time knob value
     if(knobsStates[i] == ACTIVE){
        pageValues[currentPage][i] = value;
     }
  }
}

void printAll(){
     Serial.println("");
     Serial.print("page ");
     Serial.print(currentPage);
     
     //Serial.println("");
     //printArray(knobsValues, 6);
     //Serial.println("");
     //printArray(knobsStates, 6);
     
     for(int i = 0; i < 4; i++){
       Serial.println("");
       printArray(pageValues[i], 6);
     }
}

void printArray(int *array, int len){
  for(int i = 0;i< len;i++){
       Serial.print(" ");
       Serial.print(array[i]);
  }
}
