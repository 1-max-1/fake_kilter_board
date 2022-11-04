better handling for invalid api level
instead of waiting for board to start then print API level, make it able to be queryable.
add handling for when COM port fails to open
add handling for when esp32 disconnected, for example go back to com port selection menu
Also make a refresh button on the com port selection menuadd button to be able to go back to com port selection menu
make sketch directly access sqlite database instead of python script
