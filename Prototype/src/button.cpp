#include "button.h"

ButtonManager buttonManager;

volatile bool ButtonManager::wasPressed_flag = false;
volatile bool ButtonManager::wasHeld_flag = false;
volatile unsigned long ButtonManager::buttonPressTime = 0;
volatile unsigned long ButtonManager::lastInterruptTime = 0;

bool ButtonManager::begin() {
    pinMode(BUTTON_PIN, INPUT);
    attachInterrupt(digitalPinToInterrupt(BUTTON_PIN), buttonISR, RISING);
    return true;
}

void ButtonManager::update() {
    if (buttonPressTime > 0 && !wasHeld_flag) {
        if (digitalRead(BUTTON_PIN) == HIGH && 
            (esp_timer_get_time() / 1000 - buttonPressTime) >= BUTTON_HOLD_TIME_MS) {
            wasHeld_flag = true;
        }
    }
}

bool ButtonManager::wasPressed() {
    if (wasPressed_flag) {
        wasPressed_flag = false;
        return true;
    }
    return false;
}

bool ButtonManager::wasHeld() {
    if (wasHeld_flag) {
        wasHeld_flag = false;
        return true;
    }
    return false;
}

void IRAM_ATTR ButtonManager::buttonISR() {
    unsigned long currentTime = esp_timer_get_time() / 1000;
    
    if (currentTime - lastInterruptTime > BUTTON_DEBOUNCE_MS) {
        Serial.println("Button pressed interrupt");
        wasPressed_flag = true;
        buttonPressTime = currentTime;
        lastInterruptTime = currentTime;
    }
}
