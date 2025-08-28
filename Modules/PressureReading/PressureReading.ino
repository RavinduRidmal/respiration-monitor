#include <Wire.h>
#include <Adafruit_BMP280.h> // Install from Library Manager: Adafruit BMP280

// Create BMP object
Adafruit_BMP280 bmp; 

void setup() {
  Serial.begin(115200);
  
  // Initialize I2C on GPIO21 (SDA), GPIO22 (SCL)
  Wire.begin(21, 22);

  // Try to initialize BMP280
  if (!bmp.begin(0x76)) {  // Some modules use 0x77, try that if 0x76 doesn’t work
    Serial.println("Could not find a valid BMP280 sensor, check wiring or I2C address!");
    while (1);
  }   

  Serial.println("BMP280 initialized successfully!");
}

void loop() {
  // Read values
  // float temperature = bmp.readTemperature();      // °C
  float pressure = bmp.readPressure() / 100.0F;   // hPa
  // float altitude = bmp.readAltitude(1013.25);     // meters (adjust sea level pressure if needed)

  // Print to Serial Monitor
  // Serial.print("Temperature = ");
  // Serial.print(temperature);
  // Serial.println(" *C");

  // Serial.print("Pressure = ");
  Serial.println(pressure);
  // Serial.println(" hPa");

  // Serial.print("Approx. Altitude = ");
  // Serial.print(altitude);
  // Serial.println(" m");

  // Serial.println("-----------------------------------");
  delay(20);
}
