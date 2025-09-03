#ifndef BUTTON_H
#define BUTTON_H

#include <Arduino.h>
#include "config.h"

class ButtonManager {
private:
    unsigned long lastDebounceTime;
    unsigned long buttonPressTime;
    bool lastButtonState;
    bool buttonState;
    bool wasPressed_flag;
    bool wasHeld_flag;
    
public:
    ButtonManager();
    bool begin();
    void update();
    bool wasPressed();
    bool wasHeld();
};

extern ButtonManager buttonManager;

#endif // BUTTON_H
