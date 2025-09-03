#include "sensor.h"

SensorManager sensorManager;

SensorManager::SensorManager() : ens160(ENS160_I2CADDR_0) {
    initialized = false;
    lastReadTime = 0;
    lastReading = {0, 0, 0, false, 0};
}

bool SensorManager::begin() {
    Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
    
    // Initialize AHT21 sensor for humidity and temperature
    if (!aht.begin()) {
        Serial.println("Failed to find AHT21 sensor!");
        return false;
    }
    Serial.println("AHT21 sensor initialized");
    
    // Initialize ENS160 sensor for CO2
    if (!ens160.begin()) {
        Serial.println("Failed to find ENS160 sensor!");
        return false;
    }
    Serial.println("ENS160 sensor initialized");
    
    // Set ENS160 operation mode to standard
    if (!ens160.setMode(ENS160_OPMODE_STD)) {
        Serial.println("Failed to set ENS160 operating mode!");
        return false;
    }
    delay(500); // Give sensor time to stabilize
    
    initialized = true;
    return true;
}

bool SensorManager::readSensors(SensorData& data) {
    if (!initialized) {
        Serial.println("Sensors not initialized!");
        data.valid = false;
        return false;
    }
    
    // Check if enough time has passed since last reading
    unsigned long currentTime = millis();
    if (currentTime - lastReadTime < SENSOR_READ_INTERVAL_MS && lastReading.valid) {
        data = lastReading;
        return true;
    }
    
    // Read from AHT21 (humidity and temperature)
    sensors_event_t humidity, temp;
    if (!aht.getEvent(&humidity, &temp)) {
        Serial.println("Failed to read AHT21 sensor!");
        data.valid = false;
        return false;
    }
    
    // Read from ENS160 (CO2)
    if (!ens160.measure(true)) {
        Serial.println("ENS160 measurement failed!");
        data.valid = false;
        return false;
    }
    
    // Check if data is available
    if (!ens160.available()) {
        Serial.println("ENS160 data not available!");
        data.valid = false;
        return false;
    }
    
    // Get ENS160 readings
    uint16_t eco2 = ens160.geteCO2();
    uint16_t tvoc = ens160.getTVOC();
    uint8_t aqi = ens160.getAQI();
    
    // Populate sensor data structure
    data.co2_ppm = eco2;
    data.humidity_percent = humidity.relative_humidity;
    data.temperature_celsius = temp.temperature;
    data.valid = true;
    data.timestamp = currentTime;
    
    // Store as last reading
    lastReading = data;
    lastReadTime = currentTime;
    
    // Print readings for debugging
    Serial.printf("CO2: %.1f ppm, Humidity: %.1f%%, Temperature: %.1f°C\n", 
                  data.co2_ppm, data.humidity_percent, data.temperature_celsius);
    
    return true;
}

bool SensorManager::isReady() {
    return initialized && ens160.available();
}

void SensorManager::reset() {
    lastReadTime = 0;
    lastReading.valid = false;
    
    if (initialized) {
        // Reset ENS160 if needed
        ens160.setMode(ENS160_OPMODE_RESET);
        delay(100);
        ens160.setMode(ENS160_OPMODE_STD);
    }
}

SensorData SensorManager::getLastReading() {
    return lastReading;
}

AlertLevel SensorManager::getAlertLevel(float co2_ppm) {
    if (co2_ppm <= CO2_THRESHOLD_LOW) {
        return ALERT_NONE;
    } else if (co2_ppm <= CO2_THRESHOLD_MED) {
        return ALERT_LOW;
    } else if (co2_ppm <= CO2_THRESHOLD_HIGH) {
        return ALERT_MEDIUM;
    } else {
        return ALERT_HIGH;
    }
}
