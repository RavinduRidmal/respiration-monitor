#include <Wire.h>
#include <Adafruit_AHTX0.h>
#include "ScioSense_ENS160.h"

// Create sensor objects
Adafruit_AHTX0 aht;
ScioSense_ENS160 ens160(0x53);  // ENS160 address confirmed by scanner

void setup() {
  Serial.begin(115200);
  delay(1000);

  // Initialize I2C (ESP32 SDA=21, SCL=22)
  Wire.begin(21, 22);

  // --- AHT21 init ---
  if (!aht.begin(&Wire)) {
    Serial.println("Could not find AHT21 sensor!");
    while (1) delay(10);
  }
  Serial.println("AHT21 sensor found.");

  // --- ENS160 init ---
  if (ens160.begin()) {
    Serial.print("ENS160 found. Rev: ");
    Serial.print(ens160.getMajorRev());
    Serial.print(".");
    Serial.print(ens160.getMinorRev());
    Serial.print(".");
    Serial.println(ens160.getBuild());
  } else {
    Serial.println("Could not find ENS160 sensor!");
    while (1) delay(10);
  }

  // Reset and set standard operating mode
  ens160.setMode(ENS160_OPMODE_RESET);
  delay(100);
  ens160.setMode(ENS160_OPMODE_STD);

  // Give ENS160 some time to settle
  delay(500);
}

void loop() {
  // --- Read temperature and humidity from AHT21 ---
  sensors_event_t humidity, temp;
  aht.getEvent(&humidity, &temp);

  float temperature = temp.temperature;
  float rel_humidity = humidity.relative_humidity;

  Serial.print("Temperature: ");
  Serial.print(temperature);
  Serial.println(" °C");

  Serial.print("Humidity: ");
  Serial.print(rel_humidity);
  Serial.println(" %");

  // --- ENS160 measurement ---
  if (ens160.measure()) {
    Serial.print("AQI: ");
    Serial.println(ens160.getAQI());

    Serial.print("TVOC: ");
    Serial.print(ens160.getTVOC());
    Serial.println(" ppb");

    Serial.print("eCO2: ");
    Serial.print(ens160.geteCO2());
    Serial.println(" ppm");
  } else {
    Serial.println("ENS160: Data not ready yet.");
  }

  Serial.println("---------------------------");
  delay(2000);
}
