#ifndef SENSOR_H
#define SENSOR_H

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_AHTX0.h>
#include "ScioSense_ENS160.h"
#include "config.h"

class SensorManager {
private:
    Adafruit_AHTX0 aht;
    ScioSense_ENS160 ens160;
    bool initialized;
    unsigned long lastReadTime;
    SensorData lastReading;

public:
    SensorManager();
    bool begin();
    bool readSensors(SensorData& data);
    bool isReady();
    void reset();
    SensorData getLastReading();
    AlertLevel getAlertLevel(float co2_ppm);
};

extern SensorManager sensorManager;

#endif // SENSOR_H
