#include <Arduino.h>
#include <esp_sleep.h>
#include <esp_bt.h>

#include "config.h"
#include "sensor.h"
#include "ble_comm.h"
#include "buzzer.h"
#include "button.h"

SystemState currentState = STATE_SLEEPING;
SensorData currentSensorData;
AlertLevel currentAlert = ALERT_NONE;
unsigned long lastSensorRead = 0;
bool systemInitialized = false;

// Function declarations
void setupSystem();
void enterDeepSleep();
void wakeupFromSleep();
void handleSystemStates();
void processAlerts();
void handleBLECommands();

void setup() {
    Serial.begin(115200);
    delay(1000);
    
    setupSystem();
    
    // Determine initial state based on wakeup reason
    esp_sleep_wakeup_cause_t wakeup_reason = esp_sleep_get_wakeup_cause();
    
    currentState = STATE_WAKING_UP;
    systemInitialized = true;
}

void loop() {
    if (!systemInitialized) {
        return;
    }
    
    buttonManager.update();
    buzzerManager.update();
    
    // Handle button interrupts (stop buzzer, sleep control)
    if (buttonManager.wasPressed()) {
        if (buzzerManager.isBuzzerActive()) {
            buzzerManager.stopAlert();
            Serial.println("Buzzer stopped by button press");
        }
    }
    
    if (buttonManager.wasHeld()) {
        if (currentState != STATE_SLEEPING) {
            Serial.println("Button held - preparing for sleep");
            currentState = STATE_PREPARING_SLEEP;
        }
    }
    
    // Handle BLE commands
    handleBLECommands();
    
    // Handle system state machine
    handleSystemStates();
    
    // Small delay to prevent excessive CPU usage
    delay(10);
}

void setupSystem() {
    
    // Initialize button manager first (for interrupts)
    if (!buttonManager.begin()) {
        Serial.println("Failed to initialize button manager!");
        return;
    }
    
    // Initialize buzzer
    if (!buzzerManager.begin()) {
        Serial.println("Failed to initialize buzzer manager!");
        return;
    }
    
    // Initialize sensors
    if (!sensorManager.begin()) {
        Serial.println("Failed to initialize sensor manager!");
        return;
    }
    
    // Initialize BLE
    if (!bleManager.begin()) {
        Serial.println("Failed to initialize BLE manager!");
        return;
    }
    
    // Configure deep sleep wakeup source
    esp_sleep_enable_ext0_wakeup(GPIO_NUM_14, 1);
}

void handleSystemStates() {
    unsigned long currentTime = millis();
    
    switch (currentState) {
        case STATE_WAKING_UP:
            currentState = STATE_READING_SENSORS;
            break;
            
        case STATE_READING_SENSORS:
            if (currentTime - lastSensorRead >= SENSOR_READ_INTERVAL_MS) {
                Serial.println("State: Reading Sensors");
                
                if (sensorManager.readSensors(currentSensorData)) {
                    lastSensorRead = currentTime;
                    currentState = STATE_PROCESSING_ALERTS;
                } else {
                    Serial.println("Failed to read sensors, retrying...");
                    delay(500);
                }
            }
            break;
            
        case STATE_PROCESSING_ALERTS:
            Serial.println("State: Processing Alerts");
            processAlerts();
            currentState = STATE_BLE_COMMUNICATION;
            break;
            
        case STATE_BLE_COMMUNICATION:
            // Send data via BLE if connected or within timeout
            if (bleManager.isConnected() || !bleManager.hasTimedOut()) {
                bleManager.sendSensorData(currentSensorData, currentAlert);
            }
            
            //Check if we should continue or sleep
            if (bleManager.hasTimedOut() && !bleManager.isConnected()) {
                Serial.println("BLE timeout reached");
                // currentState = STATE_PREPARING_SLEEP;
                currentState = STATE_READING_SENSORS;
            } else {
                // Continue monitoring
                currentState = STATE_READING_SENSORS;
            }
            break;
            
        case STATE_PREPARING_SLEEP:
            Serial.println("State: Preparing for Sleep");
            buzzerManager.stopAlert();
            bleManager.stop();
            
            delay(1000);
            enterDeepSleep();
            break;
            
        default:
            currentState = STATE_WAKING_UP;
            break;
    }
}

void processAlerts() {
    if (!currentSensorData.valid) {
        return;
    }
    
    AlertLevel newAlert = sensorManager.getAlertLevel(currentSensorData.co2_ppm);
    
    if (newAlert != currentAlert && newAlert != ALERT_NONE) {
        currentAlert = newAlert;
        buzzerManager.startAlert(newAlert);
        
        Serial.printf("Alert Level: %d (CO2: %.1f ppm)\n", 
                      (int)newAlert, currentSensorData.co2_ppm);
    } else if (newAlert == ALERT_NONE && currentAlert != ALERT_NONE) {
        currentAlert = ALERT_NONE;
        buzzerManager.stopAlert();
    }
}

void handleBLECommands() {
    BLECommand command = bleManager.getCommand();
    
    if (command != CMD_NONE) {
        switch (command) {
            case CMD_MUTE_BUZZER:
                buzzerManager.mute();
                Serial.println("Executed: Mute buzzer");
                break;
                
            case CMD_FORCE_SLEEP:
                Serial.println("Executed: Force sleep");
                currentState = STATE_PREPARING_SLEEP;
                break;
                
            case CMD_REQUEST_DATA:
                Serial.println("Executed: Request data");
                bleManager.sendSensorData(currentSensorData, currentAlert);
                break;
                
            case CMD_RESET_ALERTS:
                Serial.println("Executed: Reset alerts");
                buzzerManager.stopAlert();
                buzzerManager.unmute();
                currentAlert = ALERT_NONE;
                break;
                
            default:
                break;
        }
        
        bleManager.clearCommand();
    }
}

void enterDeepSleep() {    
    // Make sure button is released before sleeping
    while (digitalRead(BUTTON_PIN) == HIGH) {
        delay(100);
    }
    
    Serial.println("Button released, proceeding to sleep");
    buzzerManager.playWelcomeSound();
    Serial.flush();
    
    // Enter deep sleep
    esp_deep_sleep_start();
}