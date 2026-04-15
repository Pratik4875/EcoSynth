#include <ESP8266WiFi.h>
#include <Firebase_ESP_Client.h>

// Provide the token generation process info.
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"

// 1. WiFi & Firebase Credentials
#define WIFI_SSID "Pratik.wifi"
#define WIFI_PASSWORD "Pr@tik123"
#define API_KEY "AIzaSyDSK_GC675obkfx-mlPf7eW-aAfn4gxJwY"
#define DATABASE_URL "https://synthv1-default-rtdb.asia-southeast1.firebasedatabase.app" 

// 2. Hardware Pins
const int analogPin = A0;   
const int chargeRelay = D3; 

// 3. Firebase Objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

// Variables
const float voltageDividerRatio = 4.03; 
const float espReferenceVoltage = 3.3;
unsigned long sendDataPrevMillis = 0;

void setup() {
  Serial.begin(115200);
  pinMode(chargeRelay, OUTPUT);
  digitalWrite(chargeRelay, HIGH); // Relay OFF by default (Active-LOW)

  // Connect to WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(300);
  }
  Serial.println("\nConnected!");

  // Configure Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  // Anonymous Sign-in for testing
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase Auth Successful");
  } else {
    Serial.printf("%s\n", config.signer.signupError.message.c_str());
  }

  config.token_status_callback = tokenStatusCallback; 
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void loop() {
  // Push Telemetry every 3 seconds
  if (Firebase.ready() && (millis() - sendDataPrevMillis > 3000 || sendDataPrevMillis == 0)) {
    sendDataPrevMillis = millis();

    // Read Battery Math
    int rawADC = analogRead(analogPin);
    float pinVoltage = (rawADC / 1023.0) * espReferenceVoltage;
    float batteryVoltage = pinVoltage * voltageDividerRatio;
    int batteryPercentage = map(batteryVoltage * 100, 320, 420, 0, 100);
    batteryPercentage = constrain(batteryPercentage, 0, 100);

    // Push to Firebase
    Firebase.RTDB.setFloat(&fbdo, "/telemetry/voltage", batteryVoltage);
    Firebase.RTDB.setInt(&fbdo, "/telemetry/percentage", batteryPercentage);
    
    Serial.print("Volts: "); Serial.print(batteryVoltage);
    Serial.println(" Pushed to cloud.");
  }

  // Continuously listen for Relay Commands from Flutter
  if (Firebase.ready()) {
    if (Firebase.RTDB.getBool(&fbdo, "/control/charger_relay")) {
      bool chargeCommand = fbdo.boolData();
      
      // If Flutter says TRUE (Charge), send LOW to relay. Otherwise send HIGH.
      if (chargeCommand == true) {
        digitalWrite(chargeRelay, LOW); 
      } else {
        digitalWrite(chargeRelay, HIGH);
      }
    }
  }
}