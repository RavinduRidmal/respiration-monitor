#include "BLEDevice.h"
#include "BLEServer.h"
#include "BLE2902.h"

// BLE Server variables
BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic;
bool deviceConnected = false;

// Service and characteristic UUIDs
#define SERVICE_UUID           "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID_RX "87654321-4321-4321-4321-cba987654321"
#define CHARACTERISTIC_UUID_TX "11111111-2222-3333-4444-555555555555"

// Connection callback class
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Phone connected!");
    }

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Phone disconnected!");
      pServer->startAdvertising(); // Automatically restart advertising
    }
};

// Data receive callback class
class ReceiveCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String receivedData = String(pCharacteristic->getValue().c_str());
      
      if (receivedData.length() > 0) {
        Serial.print("Received from phone: ");
        Serial.println(receivedData);
        
        // Send response back to phone
        String response = "ESP32 got: " + receivedData;
        pTxCharacteristic->setValue(response.c_str());
        pTxCharacteristic->notify();
      }
    }
};

void setup() {
  Serial.begin(115200);
  Serial.println("ESP32 BLE Starting...");

  // Initialize BLE
  BLEDevice::init("ESP32-Phone-Link");
  
  // Create server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Create service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create TX characteristic (ESP32 sends data to phone)
  pTxCharacteristic = pService->createCharacteristic(
                    CHARACTERISTIC_UUID_TX,
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Create RX characteristic (ESP32 receives data from phone)
  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                       CHARACTERISTIC_UUID_RX,
                       BLECharacteristic::PROPERTY_WRITE
                     );
  pRxCharacteristic->setCallbacks(new ReceiveCallbacks());

  // Start service and advertising
  pService->start();
  pServer->getAdvertising()->start();
  
  Serial.println("ESP32 ready! Look for 'ESP32-Phone-Link' on your phone");
}

void loop() {
  if (deviceConnected) {
    // Send data to phone every 5 seconds
    String data = "Hello from ESP32! Time: " + String(millis()/1000) + "s";
    pTxCharacteristic->setValue(data.c_str());
    pTxCharacteristic->notify();
    
    Serial.println("Sent to phone: " + data);
    delay(5000);
  } else {
    delay(1000); // Wait for connection
  }
}

// Helper function to send custom data anytime
void sendToPhone(String message) {
  if (deviceConnected) {
    pTxCharacteristic->setValue(message.c_str());
    pTxCharacteristic->notify();
    Serial.println("Sent: " + message);
  } else {
    Serial.println("No phone connected!");
  }
}