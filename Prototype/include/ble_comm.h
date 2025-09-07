#ifndef BLE_COMM_H
#define BLE_COMM_H

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "config.h"

// BLE command types
enum BLECommand {
    CMD_NONE = 0,
    CMD_MUTE_BUZZER = 1,
    CMD_FORCE_SLEEP = 2,
    CMD_REQUEST_DATA = 3,
    CMD_RESET_ALERTS = 4
};

class BLEManager {
private:
    BLEServer* server;
    BLEService* service;
    BLECharacteristic* dataCharacteristic;
    BLECharacteristic* controlCharacteristic;
    bool oldDeviceConnected;
    unsigned long bleStartTime;
    
public:
    bool deviceConnected;
    BLECommand pendingCommand;

    BLEManager();
    bool begin();
    void sendSensorData(const SensorData& data, AlertLevel alertLevel);
    BLECommand getCommand();
    void clearCommand();
    bool isConnected();
    bool hasTimedOut();
    void stop();
};

// Callback classes
class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer);
    void onDisconnect(BLEServer* pServer);
};

class ControlCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic);
};

extern BLEManager bleManager;

#endif // BLE_COMM_H
