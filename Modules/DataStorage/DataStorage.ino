#include "FS.h"
#include "SD.h"
#include "SPI.h"

// Define SPI pins
#define SD_MISO 19
#define SD_MOSI 23
#define SD_SCLK 18
#define SD_CS   5

SPIClass spi = SPIClass(VSPI);

void setup() {
  Serial.begin(115200);

  // Initialize SPI bus with custom pins
  spi.begin(SD_SCLK, SD_MISO, SD_MOSI, SD_CS);

  if (!SD.begin(SD_CS, spi)) {
    Serial.println("Card Mount Failed!");
    return;
  }

  uint8_t cardType = SD.cardType();
  if (cardType == CARD_NONE) {
    Serial.println("No SD card attached");
    return;
  }

  Serial.print("SD Card Type: ");
  if (cardType == CARD_MMC) {
    Serial.println("MMC");
  } else if (cardType == CARD_SD) {
    Serial.println("SDSC");
  } else if (cardType == CARD_SDHC) {
    Serial.println("SDHC");
  } else {
    Serial.println("UNKNOWN");
  }

  uint64_t cardSize = SD.cardSize() / (1024 * 1024);
  Serial.printf("SD Card Size: %lluMB\n", cardSize);

  // Write to file
  File file = SD.open("/test.txt", FILE_WRITE);
  if (file) {
    file.println("Hello from ESP32!");
    file.println("Writing data to SD card works fine.");
    file.close();
    Serial.println("File written successfully.");
  } else {
    Serial.println("Failed to open file for writing.");
  }

  // Read back
  file = SD.open("/test.txt");
  if (file) {
    Serial.println("Reading back the file:");
    while (file.available()) {
      Serial.write(file.read());
    }
    file.close();
  } else {
    Serial.println("Failed to open file for reading.");
  }
}

void loop() {
  // Nothing here
}
