#include "ble_comm.h"

BLEManager bleManager;

// Global variables for callbacks
BLEManager* g_bleManager = nullptr;

BLEManager::BLEManager() {
    server = nullptr;
    service = nullptr;
    dataCharacteristic = nullptr;
    controlCharacteristic = nullptr;
    deviceConnected = false;
    oldDeviceConnected = false;
    pendingCommand = CMD_NONE;
    bleStartTime = 0;
    // Set global pointer in constructor
    g_bleManager = this;
}

bool BLEManager::begin() {
    // Ensure global pointer is set
    g_bleManager = this;
    
    // Initialize BLE
    BLEDevice::init(BLE_DEVICE_NAME);
    
    // Create BLE Server
    server = BLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());
    
    // Create BLE Service
    service = server->createService(BLE_SERVICE_UUID);
    
    // Create BLE Characteristics
    dataCharacteristic = service->createCharacteristic(
        BLE_CHAR_DATA_UUID,
        BLECharacteristic::PROPERTY_READ |
        BLECharacteristic::PROPERTY_NOTIFY
    );
    dataCharacteristic->addDescriptor(new BLE2902());
    
    controlCharacteristic = service->createCharacteristic(
        BLE_CHAR_CONTROL_UUID,
        BLECharacteristic::PROPERTY_WRITE
    );
    controlCharacteristic->setCallbacks(new ControlCallbacks());
    
    // Start the service
    service->start();
    
    // Start advertising
    BLEAdvertising* advertising = BLEDevice::getAdvertising();
    advertising->addServiceUUID(BLE_SERVICE_UUID);
    advertising->setScanResponse(false);
    advertising->setMinPreferred(0x0);
    BLEDevice::startAdvertising();
    
    bleStartTime = millis();
    Serial.println("BLE service started and advertising...");
    
    return true;
}

void BLEManager::sendSensorData(const SensorData& data, AlertLevel alertLevel) {
    if (!deviceConnected || !dataCharacteristic) {
        return;
    }
    
    // Create JSON-like string with sensor data
    String jsonData = "{";
    jsonData += "\"co2\":" + String(data.co2_ppm, 1) + ",";
    jsonData += "\"humidity\":" + String(data.humidity_percent, 1) + ",";
    jsonData += "\"temperature\":" + String(data.temperature_celsius, 1) + ",";
    jsonData += "\"alert\":" + String((int)alertLevel) + ",";
    jsonData += "\"timestamp\":" + String(data.timestamp);
    jsonData += "}";
    
    dataCharacteristic->setValue(jsonData.c_str());
    dataCharacteristic->notify();
    
    Serial.println("Sent data via BLE: " + jsonData);
}

BLECommand BLEManager::getCommand() {
    return pendingCommand;
}

void BLEManager::clearCommand() {
    pendingCommand = CMD_NONE;
}

bool BLEManager::isConnected() {
    return deviceConnected;
}

bool BLEManager::hasTimedOut() {
    return (millis() - bleStartTime) > BLE_TIMEOUT_MS;
}

void BLEManager::stop() {
    if (server) {
        server->getAdvertising()->stop();
        Serial.println("BLE advertising stopped");
    }
    // Don't set g_bleManager to nullptr here as the object still exists
}

void BLEManager::handleConnection() {
    // Handle disconnection
    if (!deviceConnected && oldDeviceConnected) {
        Serial.println("Device disconnected");
        delay(500); // Give the bluetooth stack time to process
        if (server) {
            server->startAdvertising(); // Restart advertising
            Serial.println("Restarted advertising");
        }
        oldDeviceConnected = deviceConnected;
    }
    
    // Handle new connection
    if (deviceConnected && !oldDeviceConnected) {
        Serial.println("Device connected");
        oldDeviceConnected = deviceConnected;
    }
}

// Server callback implementations
void ServerCallbacks::onConnect(BLEServer* pServer) {
    if (g_bleManager != nullptr) {
        g_bleManager->deviceConnected = true;
        Serial.println("BLE client connected");
    } else {
        Serial.println("Error: g_bleManager is null in onConnect");
    }
}

void ServerCallbacks::onDisconnect(BLEServer* pServer) {
    if (g_bleManager != nullptr) {
        g_bleManager->deviceConnected = false;
        Serial.println("BLE client disconnected");
    } else {
        Serial.println("Error: g_bleManager is null in onDisconnect");
    }
}

// Control characteristic callback implementation
void ControlCallbacks::onWrite(BLECharacteristic* pCharacteristic) {
    if (g_bleManager == nullptr) {
        Serial.println("Error: g_bleManager is null in onWrite");
        return;
    }
    
    std::string value = pCharacteristic->getValue();
    
    if (value.length() > 0) {
        Serial.print("Received BLE command: ");
        Serial.println(value.c_str());
        
        // Parse command
        int command = atoi(value.c_str());
        switch (command) {
            case 1:
                g_bleManager->pendingCommand = CMD_MUTE_BUZZER;
                Serial.println("Command: Mute buzzer");
                break;
            case 2:
                g_bleManager->pendingCommand = CMD_FORCE_SLEEP;
                Serial.println("Command: Force sleep");
                break;
            case 3:
                g_bleManager->pendingCommand = CMD_REQUEST_DATA;
                Serial.println("Command: Request data");
                break;
            case 4:
                g_bleManager->pendingCommand = CMD_RESET_ALERTS;
                Serial.println("Command: Reset alerts");
                break;
            default:
                Serial.println("Unknown command");
                break;
        }
    }
}