#ifndef BUZZER_H
#define BUZZER_H

#include <Arduino.h>
#include "config.h"

class BuzzerManager {
private:
    bool isMuted;
    AlertLevel currentAlert;
    unsigned long lastToggleTime;
    int currentRepeat;
    
    void setBuzzerPattern(AlertLevel level);
    void updateBuzzer();
    
public:
    BuzzerManager();
    bool begin();
    void startAlert(AlertLevel level);
    void stopAlert();
    void mute();
    void unmute();
    void update();
    bool isBuzzerActive();
};

extern BuzzerManager buzzerManager;

#endif // BUZZER_H
