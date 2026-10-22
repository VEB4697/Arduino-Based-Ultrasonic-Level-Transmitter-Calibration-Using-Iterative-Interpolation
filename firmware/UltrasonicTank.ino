/*
  Discrete 40 kHz tank level instrument — Day 1 firmware
  Uno D2 gates NE555 RESET, D3 receives LM393 comparator edge, D8 drives a
  low-voltage relay module input. MATLAB owns calibration and hysteresis.
  Relay output is OFF at startup, on invalid echo, and after serial timeout.
*/
#include <Arduino.h>

const uint8_t TX_GATE_PIN = 2;
const uint8_t ECHO_PIN = 3;
const uint8_t RELAY_PIN = 8;
const uint8_t RELAY_ON_LEVEL = LOW;  // Verify exact module with an LED first.
const uint8_t RELAY_OFF_LEVEL = (RELAY_ON_LEVEL == LOW) ? HIGH : LOW;

const uint16_t BURST_US = 250;       // ~10 cycles at 40 kHz
const uint32_t BLANK_US = 1500;      // tune after measuring TX ring-down
const uint32_t ECHO_TIMEOUT_US = 25000;
const uint32_t SAMPLE_PERIOD_MS = 250;
const uint32_t COMMAND_TIMEOUT_MS = 2000;
const uint16_t MIN_DISTANCE_MM = 300;  // aligns with 1.5 ms blanking and practical transducer dead zone
const uint16_t MAX_DISTANCE_MM = 4300;

volatile bool waitingForEcho = false;
volatile bool echoCaptured = false;
volatile uint32_t echoTimeUs = 0;
uint32_t latestValidMs = 0;
uint32_t latestDistanceMm = 0;
uint32_t lastCommandMs = 0;
uint32_t lastSampleMs = 0;
uint32_t lastEchoUs = 0;
bool latestValid = false;
bool relayOn = false;
char commandLine[32];
uint8_t commandLength = 0;

void echoISR() {
  if (waitingForEcho && !echoCaptured) {
    const uint32_t nowUs = micros();
    if ((uint32_t)(nowUs - lastEchoUs) >= BLANK_US) {
      echoTimeUs = nowUs - lastEchoUs;
      echoCaptured = true;
      waitingForEcho = false;
    }
  }
}

void setRelay(bool on) {
  relayOn = on;
  digitalWrite(RELAY_PIN, on ? RELAY_ON_LEVEL : RELAY_OFF_LEVEL);
}

void report(uint32_t nowMs) {
  const float distanceMm = latestValid ? (lastEchoUs * 0.343f / 2.0f) : -1.0f;
  Serial.print(F("D,")); Serial.print(nowMs);
  Serial.print(','); Serial.print(latestValid ? lastEchoUs : -1L);
  Serial.print(','); Serial.print(latestValid ? distanceMm : -1.0f, 1);
  Serial.print(','); Serial.print(latestValid ? 1 : 0);
  Serial.print(','); Serial.print(relayOn ? 1 : 0);
  Serial.println(F(",nan"));
}

void processCommand(char *line) {
  if (line[0] != 'P' || line[1] != ',') return;
  const bool requestOn = (line[2] == '1' && line[3] == '\0');
  const bool requestOff = (line[2] == '0' && line[3] == '\0');
  if (!requestOn && !requestOff) return;
  lastCommandMs = millis();

  // Independent firmware guard: no pump unless echo is recent and plausible.
  const bool safeMeasurement = latestValid &&
      (millis() - latestValidMs <= 1500) &&
      latestDistanceMm >= MIN_DISTANCE_MM &&
      latestDistanceMm <= MAX_DISTANCE_MM;
  setRelay(requestOn && safeMeasurement);
  Serial.print(F("A,")); Serial.print(requestOn ? 1 : 0);
  Serial.print(','); Serial.println(relayOn ? 1 : 0);
}

void readSerialCommands() {
  while (Serial.available() > 0) {
    const char c = (char)Serial.read();
    if (c == '\r') continue;
    if (c == '\n') {
      commandLine[commandLength] = '\0';
      processCommand(commandLine);
      commandLength = 0;
    } else if (commandLength < sizeof(commandLine) - 1) {
      commandLine[commandLength++] = c;
    } else {
      commandLength = 0;  // discard overlong command
    }
  }
}

void takeMeasurement() {
  echoCaptured = false;
  waitingForEcho = true;
  lastEchoUs = micros();
  digitalWrite(TX_GATE_PIN, HIGH);
  delayMicroseconds(BURST_US);
  digitalWrite(TX_GATE_PIN, LOW);

  const uint32_t startUs = micros();
  while (!echoCaptured && (uint32_t)(micros() - startUs) < ECHO_TIMEOUT_US) {
    readSerialCommands();
  }
  waitingForEcho = false;

  noInterrupts();
  const bool gotEcho = echoCaptured;
  const uint32_t elapsed = echoTimeUs;
  interrupts();
  if (gotEcho && elapsed >= BLANK_US && elapsed <= ECHO_TIMEOUT_US) {
    const uint32_t mm = (uint32_t)(elapsed * 0.343f / 2.0f);
    latestValid = (mm >= MIN_DISTANCE_MM && mm <= MAX_DISTANCE_MM);
    if (latestValid) {
      latestDistanceMm = mm;
      latestValidMs = millis();
      lastEchoUs = elapsed;
    }
  } else {
    latestValid = false;
  }
}

void setup() {
  pinMode(TX_GATE_PIN, OUTPUT);
  digitalWrite(TX_GATE_PIN, LOW);    // 555 held in reset through transistor
  pinMode(ECHO_PIN, INPUT);          // LM393 external pull-up to Uno +5 V
  digitalWrite(RELAY_PIN, RELAY_OFF_LEVEL);
  pinMode(RELAY_PIN, OUTPUT);
  Serial.begin(115200);
  attachInterrupt(digitalPinToInterrupt(ECHO_PIN), echoISR, RISING);
  lastCommandMs = millis();
  Serial.println(F("H,ultrasonic-tank,1,115200"));
}

void loop() {
  readSerialCommands();
  const uint32_t nowMs = millis();
  if ((uint32_t)(nowMs - lastSampleMs) >= SAMPLE_PERIOD_MS) {
    lastSampleMs = nowMs;
    takeMeasurement();
    report(millis());
  }
  if ((uint32_t)(millis() - lastCommandMs) > COMMAND_TIMEOUT_MS) setRelay(false);
  if (!latestValid || (uint32_t)(millis() - latestValidMs) > 1500) setRelay(false);
}
