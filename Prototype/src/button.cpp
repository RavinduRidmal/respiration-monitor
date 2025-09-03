#include "button.h"

ButtonManager buttonManager;

ButtonManager::ButtonManager() {
    lastDebounceTime = 0;
    buttonPressTime = 0;
    lastButtonState = HIGH;
    buttonState = HIGH;
    wasPressed_flag = false;
    wasHeld_flag = false;
}

bool ButtonManager::begin() {
    pinMode(BUTTON_PIN, INPUT_PULLUP);
    return true;
}

void ButtonManager::update() {
    int reading = digitalRead(BUTTON_PIN);
    
    // Debouncing
    if (reading != lastButtonState) {
        lastDebounceTime = millis();
    }
    
    if ((millis() - lastDebounceTime) > BUTTON_DEBOUNCE_MS) {
        if (reading != buttonState) {
            buttonState = reading;
            
            if (buttonState == LOW) {
                // Button pressed
                wasPressed_flag = true;
                buttonPressTime = millis();
            }
        }
    }
    
    // Check for held state
    if (buttonState == LOW && !wasHeld_flag) {
        if ((millis() - buttonPressTime) >= BUTTON_HOLD_TIME_MS) {
            wasHeld_flag = true;
        }
    }
    
    lastButtonState = reading;
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
