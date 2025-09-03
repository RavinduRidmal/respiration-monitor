#include "buzzer.h"

BuzzerManager buzzerManager;

BuzzerManager::BuzzerManager() {
    isMuted = false;
    currentAlert = ALERT_NONE;
    lastToggleTime = 0;
    currentRepeat = 0;
}

bool BuzzerManager::begin() {
    ledcSetup(0, 1000, 8); // Channel 0, 1000 Hz, 8-bit resolution
    ledcAttachPin(BUZZER_PIN, 0);
    ledcWrite(0, 0); // Start with buzzer off
    return true;
}

void BuzzerManager::startAlert(AlertLevel level) {
    if (isMuted || level == ALERT_NONE) {
        return;
    }

    currentAlert = level;
    currentRepeat = 0;
    lastToggleTime = millis();

    // Configure buzzer pattern
    switch (level) {
        case ALERT_LOW:
            ledcSetup(0, 800, 8);
            break;
        case ALERT_MEDIUM:
            ledcSetup(0, 1200, 8);
            break;
        case ALERT_HIGH:
            ledcSetup(0, 1800, 8);
            break;
        case ALERT_CRITICAL:
            ledcSetup(0, 2500, 8);
            break;
        default:
            ledcWrite(0, 0);
            return;
    }

    ledcWrite(0, 128); // Start buzzer with 50% duty cycle
    Serial.printf("Started buzzer alert level %d\n", (int)level);
}

void BuzzerManager::stopAlert() {
    currentAlert = ALERT_NONE;
    currentRepeat = 0;
    ledcWrite(0, 0); // Turn off buzzer
    Serial.println("Stopped buzzer alert");
}

void BuzzerManager::mute() {
    isMuted = true;
    ledcWrite(0, 0); // Turn off buzzer
    Serial.println("Buzzer muted");
}

void BuzzerManager::unmute() {
    isMuted = false;
    Serial.println("Buzzer unmuted");
}

void BuzzerManager::update() {
    if (currentAlert == ALERT_NONE || isMuted) {
        return;
    }

    unsigned long currentTime = millis();

    if (currentTime - lastToggleTime >= 500) {
        lastToggleTime = currentTime;
        currentRepeat++;

        if (currentRepeat % 2 == 0) {
            ledcWrite(0, 128); // Turn buzzer on
        } else {
            ledcWrite(0, 0); // Turn buzzer off
        }

        // Stop after a fixed number of repeats
        if (currentRepeat >= 10) {
            stopAlert();
        }
    }
}

bool BuzzerManager::isBuzzerActive() {
    return (currentAlert != ALERT_NONE && !isMuted);
}