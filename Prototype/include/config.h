#ifndef CONFIG_H
#define CONFIG_H

// Pin definitions
#define I2C_SDA_PIN         21    // SDA pin for ENS160 + AHT21 sensors
#define I2C_SCL_PIN         22    // SCL pin for ENS160 + AHT21 sensors
#define BUTTON_PIN          14    // Push button pin (with internal pull-up)
#define BUZZER_PIN          4     // Buzzer PWM pin

// Wake up source
#define BUTTON_PIN_BITMASK  (1ULL << BUTTON_PIN)

// Alert thresholds (CO2 in ppm)
#define CO2_THRESHOLD_LOW    1000
#define CO2_THRESHOLD_MED    5000
#define CO2_THRESHOLD_HIGH   10000

// Alert levels
enum AlertLevel {
    ALERT_NONE = 0,
    ALERT_LOW = 1,     // CO2 > 1000 ppm
    ALERT_MEDIUM = 2,  // CO2 > 5000 ppm
    ALERT_HIGH = 3,     // CO2 > 10000 ppm
    ALERT_CRITICAL = 4  // Critical alert level
};

// Sensor data structure
struct SensorData {
    float co2_ppm;
    float humidity_percent;
    float temperature_celsius;
    bool valid;
    unsigned long timestamp;
};

// System states
enum SystemState {
    STATE_SLEEPING,
    STATE_WAKING_UP,
    STATE_READING_SENSORS,
    STATE_PROCESSING_ALERTS,
    STATE_BLE_COMMUNICATION,
    STATE_PREPARING_SLEEP
};

// Timing constants
#define BUTTON_DEBOUNCE_MS      50
#define BUTTON_HOLD_TIME_MS     2000
#define SENSOR_READ_INTERVAL_MS 1000
#define BLE_TIMEOUT_MS          30000
#define BUZZER_TIMEOUT_MS       10000

// BLE constants
#define BLE_DEVICE_NAME         "RespirationMonitor"
#define BLE_SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define BLE_CHAR_DATA_UUID      "87654321-4321-4321-4321-cba987654321"
#define BLE_CHAR_CONTROL_UUID   "11111111-2222-3333-4444-555555555555"

#endif // CONFIG_H
