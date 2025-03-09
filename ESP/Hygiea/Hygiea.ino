#include <OneWire.h>
#include <DallasTemperature.h>
#include <driver/adc.h>  // ESP32 ADC Driver
#include <FirebaseESP8266.h>
#include <WiFi.h>

// Temperature Sensors
#define ONE_WIRE_BUS_1 4  // GPIO4 - Input DS18B20
#define ONE_WIRE_BUS_2 5  // GPIO5 - Chamber DS18B20

OneWire oneWire1(ONE_WIRE_BUS_1);
DallasTemperature tempSensor1(&oneWire1);

OneWire oneWire2(ONE_WIRE_BUS_2);
DallasTemperature tempSensor2(&oneWire2);

// Relays (Active-Low Configuration)
#define RELAY_PUMP 26  // GPIO26 - Pump to transfer urine
#define RELAY_FLUSH 27 // GPIO27 - Flush pump
#define RELAY_UV 25    // GPIO25 - UV Light

// Analog Sensors
#define PH_SENSOR 32
#define TDS_SENSOR 33
#define TURBIDITY_SENSOR 34

// Firebase Objects
FirebaseData firebaseData;
FirebaseAuth auth;
FirebaseConfig config;

void setupWiFi() {
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    Serial.print("Connecting to WiFi");
    while (WiFi.status() != WL_CONNECTED) {
        Serial.print(".");
        delay(300);
    }
    Serial.println("\nWiFi Connected");
}

void setupFirebase() {
    config.database_url = FIREBASE_HOST;
    config.signer.tokens.legacy_token = FIREBASE_AUTH;

    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);
}

void setup() {
    Serial.begin(115200);
    Serial.println("Initializing sensors...");

    tempSensor1.begin();
    tempSensor2.begin();

    pinMode(RELAY_PUMP, OUTPUT);
    pinMode(RELAY_FLUSH, OUTPUT);
    pinMode(RELAY_UV, OUTPUT);

    // Set relays to HIGH (OFF) initially
    digitalWrite(RELAY_PUMP, HIGH);
    digitalWrite(RELAY_FLUSH, HIGH);
    digitalWrite(RELAY_UV, HIGH);

    // Set ADC attenuation for better range (0-3.3V)
    analogReadResolution(12);  // 12-bit ADC (0-4095)
    analogSetPinAttenuation(PH_SENSOR, ADC_11db);
    analogSetPinAttenuation(TDS_SENSOR, ADC_11db);
    analogSetPinAttenuation(TURBIDITY_SENSOR, ADC_11db);

    setupWiFi();
    setupFirebase();

    Serial.println("System Ready.");
}

void loop() {
    Serial.println("\n[1/7] Reading Input Temperature Sensor...");
    tempSensor1.requestTemperatures();
    float temp1 = tempSensor1.getTempCByIndex(0);
    Serial.print("Temperature at Input: ");
    Serial.print(temp1);
    Serial.println(" °C");
    delay(2000);

    Serial.println("Urine detected! Activating Pump...");
    Serial.println("\n[2/7] Activating Pump...");
    digitalWrite(RELAY_PUMP, LOW);
    delay(30000);
    digitalWrite(RELAY_PUMP, HIGH);
    Serial.println("Waiting for chamber stabilization...");
    delay(5000);

    Serial.println("\n[3/7] Reading Chamber Temperature...");
    tempSensor2.requestTemperatures();
    float temp2 = tempSensor2.getTempCByIndex(0);
    Serial.print("Temperature in Chamber: ");
    Serial.print(temp2);
    Serial.println(" °C");
    delay(2000);

    Serial.println("\n[4/7] Reading pH Sensor...");
    int ph_raw = analogRead(PH_SENSOR);
    float ph_value = map(ph_raw, 0, 4095, 0, 14);  // Convert raw value to pH range
    Serial.print("pH Value: ");
    Serial.println(ph_value);
    delay(2000);

    Serial.println("\n[5/7] Reading TDS Sensor...");
    int tds_raw = analogRead(TDS_SENSOR);
    float tds_value = (tds_raw / 4095.0) * 1000;  // Approximate conversion
    Serial.print("TDS Value (ppm): ");
    Serial.println(tds_value);
    delay(2000);

    Serial.println("\n[6/7] Reading Turbidity Sensor...");
    int turbidity_raw = analogRead(TURBIDITY_SENSOR);
    float turbidity_value = map(turbidity_raw, 0, 4095, 0, 100); // Convert raw to percentage
    Serial.print("Turbidity Level: ");
    Serial.print(turbidity_value);
    Serial.println(" %");
    delay(2000);

    Serial.println("\n[7/7] Flushing Chamber...");
    digitalWrite(RELAY_FLUSH, LOW);
    delay(5000);
    digitalWrite(RELAY_FLUSH, HIGH);

    Serial.println("\n[8/8] Activating UV Light...");
    digitalWrite(RELAY_UV, LOW);
    delay(5000);
    digitalWrite(RELAY_UV, HIGH);

    Serial.println("\nUploading data to Firebase...");
    sendToFirebase(temp1, temp2, ph_value, tds_value, turbidity_value);

    Serial.println("\nCycle complete. Waiting for next sample...");
    delay(10000);
}

void sendToFirebase(float temp1, float temp2, float pH, float tds, float turbidity) {
    if (Firebase.setFloat(firebaseData, "/HygieaData/temperature", temperature)) {
        Serial.println("Temperature sent");
    } else {
        Serial.println("Failed to send Temperature: " + firebaseData.errorReason());
    }

    if (Firebase.setFloat(firebaseData, "/HygieaData/ph", ph)) {
        Serial.println("pH sent");
    } else {
        Serial.println("Failed to send pH: " + firebaseData.errorReason());
    }

    if (Firebase.setFloat(firebaseData, "/HygieaData/turbidity", turbidity)) {
        Serial.println("Turbidity sent");
    } else {
        Serial.println("Failed to send Turbidity: " + firebaseData.errorReason());
    }

    if (Firebase.setFloat(firebaseData, "/HygieaData/tds", tds)) {
        Serial.println("TDS sent");
    } else {
        Serial.println("Failed to send TDS: " + firebaseData.errorReason());
    }

    delay(1000);
}
