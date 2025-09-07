#ifndef BUTTON_H
#define BUTTON_H

#include <Arduino.h>
#include "config.h"

class ButtonManager {
private:
    static volatile bool wasPressed_flag;
    static volatile bool wasHeld_flag;
    static volatile unsigned long buttonPressTime;
    static volatile unsigned long lastInterruptTime;
    static void IRAM_ATTR buttonISR();
    
public:
    bool begin();
    void update();
    bool wasPressed();
    bool wasHeld();
};

extern ButtonManager buttonManager;

#endif // BUTTON_H
