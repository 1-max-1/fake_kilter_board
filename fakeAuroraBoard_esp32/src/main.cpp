#include <Arduino.h>
#include <BLEDevice.h>

// The name that will come up in the list in the kilter board app.
// Must be alphanumeric.
#define DISPLAY_NAME "Fake Kilter Board"

// Aurora API level. must be nonzero, positive, single-digit integer.
// API level 3+ uses a different protocol than API levels 1 and 2 and below.
#define API_LEVEL 3

// Extracted by decompiling kilter board app, in file BluetoothServiceKt.java
#define ADVERTISING_SERVICE_UUID "4488B571-7806-4DF6-BCFF-A2897E4953FF"
#define DATA_TRANSFER_SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define DATA_TRANSFER_CHARACTERISTIC "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

class BLECharacteristicCallbacksOverride : public BLECharacteristicCallbacks {
public:
	// Whenever data is sent to the esp32 we just immediately pass it onto the dekstop app to do all of
	void onWrite(BLECharacteristic* pCharacteristic) {
		if(pCharacteristic->getUUID().toString() == BLEUUID(DATA_TRANSFER_CHARACTERISTIC).toString()) {
			Serial.write(pCharacteristic->getValue().c_str(), pCharacteristic->getValue().length());
		}
	}
};

bool restartAdvertising = false;

// When a device connects or disconnects the server will stop advertising, so we need to restart it to be discoverable again.
class BLEServerCallbacksOverride: public BLEServerCallbacks {
	void onConnect(BLEServer* pServer) {
		restartAdvertising = true;
	}
	void onDisconnect(BLEServer* pServer) {
		restartAdvertising = true;
	}
};

BLECharacteristicCallbacksOverride characteristicCallbacks;
BLEServerCallbacksOverride serverCallbacks;
BLEServer* bleServer = nullptr;

void setup() {
	Serial.begin(115200);
	Serial.write(4);
	Serial.write(API_LEVEL);

	char boardName[2 + sizeof(DISPLAY_NAME)];
	snprintf(boardName, sizeof(boardName), "%s%s%d", DISPLAY_NAME, "@", API_LEVEL);
	BLEDevice::init(boardName);
	bleServer = BLEDevice::createServer();
	bleServer->setCallbacks(&serverCallbacks);

	// This service + characteristic is how the app sends data to the board
	BLEService* service = bleServer->createService(DATA_TRANSFER_SERVICE_UUID);
	BLECharacteristic* characteristic = service->createCharacteristic(DATA_TRANSFER_CHARACTERISTIC, BLECharacteristic::PROPERTY_WRITE);
	characteristic->setCallbacks(&characteristicCallbacks);
	service->start();
	
	// Advertising service, this is how the app detects an Aurora board
	BLEService* advertisingService = bleServer->createService(ADVERTISING_SERVICE_UUID);
	advertisingService->start();

	BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
	pAdvertising->addServiceUUID(ADVERTISING_SERVICE_UUID);
	pAdvertising->setScanResponse(true);
	pAdvertising->setMinPreferred(0x06);  // Functions that help with iPhone connections issue
	pAdvertising->setMinPreferred(0x12);
	BLEDevice::startAdvertising();
}

void loop() {
	if (restartAdvertising) {
		delay(500); // Let the bluetooth hardware sort itself out
		restartAdvertising = false;
		bleServer->startAdvertising();
	}

	// If the processing sketch pings us then we send it the API level.
	if (Serial.available() > 0 && Serial.read() == 4) {
		Serial.write(4);
		Serial.write(API_LEVEL);
	}
}